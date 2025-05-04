// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "script/utils/Network.sol";

import { MapTokenConfig } from "script/20252802-remap-tokens-testnet/MapTokenConfig.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";

contract Migration__20252802_MapTokens_Mainchain is MapTokenConfig {
  using LibCompanionNetwork for *;
  using LibProxy for *;

  address internal constant _SM_GOVERNOR = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
  address internal constant _EXECUTOR = _SM_GOVERNOR;

  address[] internal mockGvs;
  address[] internal mockOps;

  Proposal.ProposalDetail internal _proposal;
  IRoninBridgeManager internal _ronBM;
  IMainchainBridgeManager internal _ethBM;

  function run() public virtual override {
    super.run();

    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;
    (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) = getMainchainMapData();

    TNetwork companionNetwork = config.getCompanionNetwork(network());
    uint256 companionChainId = LibCompanionNetwork.companionChainId();

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
