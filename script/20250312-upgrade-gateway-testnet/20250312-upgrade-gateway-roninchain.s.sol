// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { AssetMigration } from "@ronin/contracts/extensions/AssetMigration.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "script/utils/Network.sol";

import { Migration } from "script/Migration.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";

contract Migration__20250312_UpgradeRoninGatewayV3_Roninchain is Migration {
  using LibCompanionNetwork for *;
  using LibProxy for *;

  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 30 minutes;

  address internal constant _SM_GOVERNOR = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
  address internal constant _EXECUTOR = _SM_GOVERNOR;

  address[] internal mockGvs;
  address[] internal mockOps;

  Proposal.ProposalDetail internal _proposal;
  IRoninBridgeManager internal _ronBM;

  function run() public virtual {
    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    address newGwLogic = _deployLogic(Contract.RoninGatewayV3.key());

    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    TNetwork companionNetwork = config.getCompanionNetwork(network());
    uint256 companionChainId = LibCompanionNetwork.companionChainId();

    targets[0] = loadContract(Contract.RoninGatewayV3.key());
    values[0] = 0;
    callDatas[0] = abi.encodeWithSignature("upgradeTo(address)", newGwLogic);
    gasAmounts[0] = 1_000_000;

    uint256 nonce = _ronBM.round(block.chainid) + 1;
    LibProposal.createProposal(address(_ronBM), nonce, expiry, targets, values, callDatas, gasAmounts);

    vm.broadcast(_SM_GOVERNOR);
    vm.recordLogs();
    _ronBM.propose(block.chainid, expiry, _EXECUTOR, targets, values, callDatas, gasAmounts);
    Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
    for (uint256 i; i < recordedLogs.length; ++i) {
      if (recordedLogs[i].emitter == address(_ronBM) && recordedLogs[i].topics[0] == IRoninBridgeManager.ProposalCreated.selector) {
        (_proposal,) = abi.decode(recordedLogs[i].data, (Proposal.ProposalDetail, address));
        break;
      }
    }

    LibProposal.voteFor(_ronBM, _proposal);
  }
}
