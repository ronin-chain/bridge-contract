// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { AssetMigration } from "@ronin/contracts/extensions/AssetMigration.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "script/utils/Network.sol";

import { Migration } from "script/Migration.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";

contract Migration__20252802_SetWethTokenMainchain_Mainchain is Migration {
  using LibCompanionNetwork for *;
  using LibProxy for *;

  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 30 minutes;

  address internal constant _SM_GOVERNOR = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
  address internal constant _EXECUTOR = _SM_GOVERNOR;

  // verify token contract: https://sepolia.etherscan.io/address/0x097d90c9d3e0b50ca60e1ae45f6a81010f9fb534
  // verify ccip token pool: https://sepolia.etherscan.io/address/0x968ee1e1A54B7d6273801AdefC4165823DeE6123#readContract#F14
  // source of truth: https://sky-mavis.slack.com/archives/C07QP0QALRZ/p1740507102381399?thread_ts=1739171994.436029&cid=C07QP0QALRZ
  address internal constant _CCIP_MOCK_WETH = 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534;
  address internal constant _CCIP_WETH_POOL = 0x968ee1e1A54B7d6273801AdefC4165823DeE6123;

  address[] internal mockGvs;
  address[] internal mockOps;

  Proposal.ProposalDetail internal _proposal;
  IRoninBridgeManager internal _ronBM;
  IMainchainBridgeManager internal _ethBM;

  function run() public virtual {
    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;
    // (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) = getMainchainMapData();
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    TNetwork companionNetwork = config.getCompanionNetwork(network());
    uint256 companionChainId = LibCompanionNetwork.companionChainId();

    targets[0] = config.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());
    values[0] = 0;
    address[] memory tokens = new address[](1);
    tokens[0] = _CCIP_MOCK_WETH;
    address[] memory recipients = new address[](1);
    recipients[0] = _CCIP_WETH_POOL;
    uint64[] memory remoteChainSelectors = new uint64[](1);
    remoteChainSelectors[0] = 13116810400804392105;
    callDatas[0] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", abi.encodeWithSelector(AssetMigration.whitelist.selector, tokens, recipients, remoteChainSelectors)
    );
    gasAmounts[0] = 1_000_000;

    _ethBM = IMainchainBridgeManager(config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key()));
    LibProposal.verifyMainchainProposalGasAmount(companionNetwork, address(_ethBM), targets, values, callDatas, gasAmounts);

    vm.broadcast(_SM_GOVERNOR);
    vm.recordLogs();
    _ronBM.propose(companionChainId, expiry, _EXECUTOR, targets, values, callDatas, gasAmounts);
    Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
    for (uint256 i; i < recordedLogs.length; ++i) {
      if (recordedLogs[i].emitter == address(_ronBM) && recordedLogs[i].topics[0] == IRoninBridgeManager.ProposalCreated.selector) {
        (_proposal,) = abi.decode(recordedLogs[i].data, (Proposal.ProposalDetail, address));
        break;
      }
    }

    SignatureConsumer.Signature[] memory sigs = LibProposal.voteForBySignature(_ronBM, _proposal, Ballot.VoteType.For);

    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(config.getCompanionNetwork(network()));
    vm.broadcast(_SM_GOVERNOR);
    _ethBM.relayProposal(_proposal, new Ballot.VoteType[](sigs.length), sigs);
  }
}
