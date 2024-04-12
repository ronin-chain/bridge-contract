// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BasePostCheck } from "../../BasePostCheck.s.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { TContract, Contract } from "script/utils/Contract.sol";
import "script/shared/libraries/LibProposal.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

abstract contract PostCheck_BridgeManager_Proposal is BasePostCheck {
  using LibArray for *;
  using LibProxy for *;
  using LibProposal for *;

  uint96[] private _voteWeights = [100, 100];
  address[] private _addingGovernors = [makeAddr("governor-1"), makeAddr("governor-2")];
  address[] private _addingOperators = [makeAddr("operator-1"), makeAddr("operator-2")];
  address[] private _proxyTargets;

  modifier onlyOnRoninNetwork() {
    require(
      block.chainid == DefaultNetwork.RoninMainnet.chainId() || block.chainid == DefaultNetwork.RoninTestnet.chainId()
        || block.chainid == Network.RoninDevnet.chainId() || block.chainid == DefaultNetwork.Local.chainId(),
      "chainid != RoninMainnet or RoninTestnet"
    );
    _;
  }

  function _validate_BridgeManager_Proposal() internal {
    validate_ProposeGlobalProposalAndRelay_addBridgeOperator();
    validate_canExecuteUpgradeSingleProposal();
  }

  function validate_ProposeGlobalProposalAndRelay_addBridgeOperator() private onPostCheck("validate_ProposeGlobalProposalAndRelay_addBridgeOperator") {
    RoninBridgeManager manager = RoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 totalVoteWeight = manager.getTotalWeight();

    uint256 cheatVoteWeight = totalVoteWeight * 2;
    address cheatOperator = makeAddr(string.concat("operator-", vm.toString(seed)));
    (address cheatGovernor, uint256 cheatGovernorPk) = makeAddrAndKey(string.concat("governor-", vm.toString(seed)));

    vm.prank(address(manager));
    bool[] memory addeds =
      manager.addBridgeOperators(cheatVoteWeight.toSingletonArray().toUint96sUnsafe(), cheatGovernor.toSingletonArray(), cheatOperator.toSingletonArray());
    assertTrue(addeds[0], "addeds[0] == false");

    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = GlobalProposal.TargetOption.BridgeManager;

    GlobalProposal.GlobalProposalDetail memory globalProposal = LibProposal.createGlobalProposal({
      expiryTimestamp: block.timestamp + 20 minutes,
      targetOptions: targetOptions,
      values: uint256(0).toSingletonArray(),
      calldatas: abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)).toSingletonArray(),
      gasAmounts: uint256(1_000_000).toSingletonArray(),
      nonce: manager.round(block.chainid) + 1
    });

    SignatureConsumer.Signature[] memory signatures = globalProposal.generateSignaturesGlobal(cheatGovernorPk.toSingletonArray(), Ballot.VoteType.For);
    Ballot.VoteType[] memory _supports = new Ballot.VoteType[](signatures.length);

    vm.prank(cheatGovernor);
    manager.proposeGlobalProposalStructAndCastVotes(globalProposal, _supports, signatures);

    // Check if the proposal is voted
    assertEq(manager.globalProposalVoted(globalProposal.nonce, cheatGovernor), true);
    // Check if the operator is added
    assertTrue(manager.isBridgeOperator(cheatOperator), "operator not added");
    // // Check if the governor is added
    // assertTrue(manager.isBridgeGovernor(cheatGovernor), "governor not added");

  }

  function validate_canExecuteUpgradeSingleProposal() private onlyOnRoninNetwork onPostCheck("validate_canExecuteUpgradeProposal") {
    address manager = loadContract(Contract.RoninBridgeManager.key());
    // Get all contracts deployed from the current network
    address payable[] memory addrs = CONFIG.getAllAddresses(network());

    // Identify proxy targets to upgrade with proposal
    for (uint256 i; i < addrs.length; ++i) {
      address payable proxy = addrs[i].getProxyAdmin({ nullCheck: false });
      if (proxy == manager) {
        console.log("Target Proxy to test upgrade with proposal", vm.getLabel(addrs[i]));
        _proxyTargets.push(addrs[i]);
      }
    }

    address[] memory targets = _proxyTargets;
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = CONFIG.getContractTypeFromCurrentNetwok(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType);
    }
  }
}
