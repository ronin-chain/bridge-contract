// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import { GatewayUpgradeConfig } from "./GatewayUpgradeConfig.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__20250604_UpgradeGateway_Roninchain is GatewayUpgradeConfig {
  Proposal.ProposalDetail internal _proposal;
  IRoninBridgeManager internal _ronBM;

  function run() public virtual {
    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;

    (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) = _getRoninUpgradeData();

    uint256 nonce = _ronBM.round(block.chainid) + 1;
    _proposal = LibProposal.createProposal(address(_ronBM), nonce, expiry, targets, values, callDatas, gasAmounts);
    _proposal.executor = _SM_EXECUTOR;

    vm.broadcast(_SM_GOVERNOR);
    _ronBM.propose(block.chainid, expiry, _SM_EXECUTOR, targets, values, callDatas, gasAmounts);
  }

  function _getRoninUpgradeData()
    internal
    view
    returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts)
  {
    // Get gateway proxy address
    address gatewayProxy = loadContract(Contract.RoninGatewayV3.key());

    // Create arrays for 2 operations
    targets = new address[](1);
    values = new uint256[](1);
    callDatas = new bytes[](1);
    gasAmounts = new uint256[](1);

    // First operation: Upgrade to burn all logic and initialize V5
    targets[0] = gatewayProxy;
    values[0] = 0;
    callDatas[0] = abi.encodeCall(ITransparentUpgradeableProxyV2.upgradeToAndCall, (_BURN_ALL_LOGIC, abi.encodeWithSignature("initializeV5()")));
    gasAmounts[0] = 1_000_000;

    // // Second operation: Upgrade to NFT approval logic and set bulk approval
    // Get NFT data
    // (address[] memory nfts, address[] memory operators, bool[] memory approveds) = _getRoninNftData();
    // targets[1] = gatewayProxy;
    // values[1] = 0;
    // callDatas[1] = abi.encodeCall(
    //   ITransparentUpgradeableProxyV2.upgradeToAndCall,
    //   (_NFT_APPROVAL_LOGIC_RONIN, abi.encodeWithSignature("bulkSetApprovalForAll(address[],address[],bool[])", nfts, operators, approveds))
    // );
    // gasAmounts[1] = 1_000_000;
  }

  function _afterRunningScript() internal virtual override { }

  function _postCheck() internal virtual override {
    LibProposal.voteFor(_ronBM, _proposal);

    // Execute the proposal if executor is set
    if (_proposal.executor != address(0)) {
      vm.prank(_proposal.executor);
      _ronBM.execute(_proposal);
    }

    // Uncomment below to run full post check
    // super._postCheck();
  }
}
