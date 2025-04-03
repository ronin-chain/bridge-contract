// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import { MapTokenConfig } from "script/20252802-remap-tokens-testnet/MapTokenConfig.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__20252802_MapTokens_Roninchain is MapTokenConfig {
  address internal constant _SM_GOVERNOR = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
  address internal constant _EXECUTOR = address(0);

  Proposal.ProposalDetail internal _proposal;
  IRoninBridgeManager internal _ronBM;

  function run() public virtual override {
    super.run();

    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;
    (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) = getRoninMapData();
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
