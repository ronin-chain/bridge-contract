// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxyV2, TransparentUpgradeableProxy } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { BasePostCheck } from "../../BasePostCheck.s.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { TContract, Contract } from "script/utils/Contract.sol";
import { TNetwork, Network } from "script/utils/Network.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Ballot, SignatureConsumer, Proposal, GlobalProposal, LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

abstract contract PostCheck_BridgeManager_Proposal is BasePostCheck {
  using LibArray for *;
  using LibProxy for *;
  using LibProposal for *;
  using LibCompanionNetwork for *;

  uint96[] private _voteWeights = [100, 100];
  address[] private _addingGovernors = [makeAddr("governor-1"), makeAddr("governor-2")];
  address[] private _addingOperators = [makeAddr("operator-1"), makeAddr("operator-2")];

  function _validate_BridgeManager_Proposal() internal {
    validate_relayUpgradeProposal();
    validate_ProposeGlobalProposalAndRelay_addBridgeOperator();
    validate_proposeAndRelay_addBridgeOperator();
    validate_canExecuteUpgradeSingleProposal();
    validate_canExcuteUpgradeAllOneProposal();
  }

  function validate_proposeAndRelay_addBridgeOperator() private onlyOnRoninNetworkOrLocal onPostCheck("validate_proposeAndRelay_addBridgeOperator") {
    RoninBridgeManager manager = RoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));

    // Cheat add governor
    cheatAddOverWeightedGovernor(address(manager));

    address[] memory targets = address(manager).toSingletonArray();
    uint256[] memory values = uint256(0).toSingletonArray();
    bytes[] memory calldatas = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      (abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)))
    ).toSingletonArray();
    uint256[] memory gasAmounts = uint256(1_000_000).toSingletonArray();

    uint256 roninChainId = block.chainid;

    Proposal.ProposalDetail memory proposal = LibProposal.createProposal({
      manager: address(manager),
      expiryTimestamp: block.timestamp + 20 minutes,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts,
      nonce: manager.round(0) + 1
    });

    vm.prank(cheatGovernor);
    manager.propose(roninChainId, block.timestamp + 20 minutes, address(0x0), targets, values, calldatas, gasAmounts);

    {
      TNetwork currentNetwork = CONFIG.getCurrentNetwork();
      (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();

      CONFIG.createFork(companionNetwork);
      CONFIG.switchTo(companionNetwork);

      MainchainBridgeManager mainchainManager = MainchainBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));

      uint256 snapshotId = vm.snapshot();

      // Cheat add governor
      cheatAddOverWeightedGovernor(address(mainchainManager));

      targets = address(mainchainManager).toSingletonArray();

      proposal = LibProposal.createProposal({
        manager: address(mainchainManager),
        expiryTimestamp: block.timestamp + 20 minutes,
        targets: targets,
        values: proposal.values,
        calldatas: proposal.calldatas,
        gasAmounts: proposal.gasAmounts,
        nonce: mainchainManager.round(block.chainid) + 1
      });

      SignatureConsumer.Signature[] memory signatures = proposal.generateSignatures(cheatGovernorPk.toSingletonArray(), Ballot.VoteType.For);
      Ballot.VoteType[] memory _supports = new Ballot.VoteType[](signatures.length);

      uint256 minimumForVoteWeight = mainchainManager.minimumVoteWeight();
      uint256 totalForVoteWeight = mainchainManager.getGovernorWeight(cheatGovernor);
      console.log("Total for vote weight:", totalForVoteWeight);
      console.log("Minimum for vote weight:", minimumForVoteWeight);

      vm.prank(cheatGovernor);
      mainchainManager.relayProposal(proposal, _supports, signatures);
      for (uint256 i; i < _addingGovernors.length; ++i) {
        assertEq(mainchainManager.isBridgeOperator(_addingOperators[i]), true, "isBridgeOperator == false");
      }

      bool reverted = vm.revertTo(snapshotId);
      assertTrue(reverted, "Cannot revert to snapshot id");
      CONFIG.switchTo(currentNetwork);
    }
  }

  function validate_relayUpgradeProposal() private onPostCheck("validate_relayUpgradeProposal") {
    TNetwork currentNetwork = CONFIG.getCurrentNetwork();
    (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();

    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    MainchainBridgeManager mainchainManager = MainchainBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));

    uint256 snapshotId = vm.snapshot();

    // Cheat add governor
    {
      cheatAddOverWeightedGovernor(address(mainchainManager));

      address[] memory targets = new address[](3);
      uint256[] memory values = new uint256[](3);
      uint256[] memory gasAmounts = new uint256[](3);
      bytes[] memory calldatas = new bytes[](3);
      address[] memory logics = new address[](3);

      targets[0] = address(mainchainManager);
      targets[1] = loadContract(Contract.MainchainGatewayV3.key());
      targets[2] = loadContract(Contract.MainchainPauseEnforcer.key());

      logics[0] = _deployLogic(Contract.MainchainBridgeManager.key());
      logics[1] = _deployLogic(Contract.MainchainGatewayV3.key());
      logics[2] = _deployLogic(Contract.MainchainPauseEnforcer.key());

      calldatas[0] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[0]));
      calldatas[1] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[1]));
      calldatas[2] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[2]));

      gasAmounts[0] = 1_000_000;
      gasAmounts[1] = 1_000_000;
      gasAmounts[2] = 1_000_000;

      Proposal.ProposalDetail memory proposal = LibProposal.createProposal({
        manager: address(mainchainManager),
        expiryTimestamp: block.timestamp + 20 minutes,
        targets: targets,
        values: values,
        calldatas: calldatas,
        gasAmounts: gasAmounts,
        nonce: mainchainManager.round(block.chainid) + 1
      });

      SignatureConsumer.Signature[] memory signatures = proposal.generateSignatures(cheatGovernorPk.toSingletonArray(), Ballot.VoteType.For);
      Ballot.VoteType[] memory _supports = new Ballot.VoteType[](signatures.length);

      uint256 minimumForVoteWeight = mainchainManager.minimumVoteWeight();
      uint256 totalForVoteWeight = mainchainManager.getGovernorWeight(cheatGovernor);
      console.log("Total for vote weight:", totalForVoteWeight);
      console.log("Minimum for vote weight:", minimumForVoteWeight);

      vm.prank(cheatGovernor);
      mainchainManager.relayProposal(proposal, _supports, signatures);

      assertEq(payable(address(mainchainManager)).getProxyImplementation(), logics[0], "MainchainBridgeManager logic is not upgraded");
      assertEq(loadContract(Contract.MainchainGatewayV3.key()).getProxyImplementation(), logics[1], "MainchainGatewayV3 logic is not upgraded");
      assertEq(loadContract(Contract.MainchainPauseEnforcer.key()).getProxyImplementation(), logics[2], "MainchainPauseEnforcer logic is not upgraded");
    }

    bool reverted = vm.revertTo(snapshotId);
    assertTrue(reverted, "Cannot revert to snapshot id");
    CONFIG.switchTo(currentNetwork);
  }

  function validate_ProposeGlobalProposalAndRelay_addBridgeOperator()
    private
    onlyOnRoninNetworkOrLocal
    onPostCheck("validate_ProposeGlobalProposalAndRelay_addBridgeOperator")
  {
    RoninBridgeManager manager = RoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    cheatAddOverWeightedGovernor(address(manager));

    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = GlobalProposal.TargetOption.BridgeManager;

    GlobalProposal.GlobalProposalDetail memory globalProposal = LibProposal.createGlobalProposal({
      expiryTimestamp: block.timestamp + 20 minutes,
      targetOptions: targetOptions,
      values: uint256(0).toSingletonArray(),
      calldatas: abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        (abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)))
      ).toSingletonArray(),
      gasAmounts: uint256(1_000_000).toSingletonArray(),
      nonce: manager.round(0) + 1
    });

    SignatureConsumer.Signature[] memory signatures;
    Ballot.VoteType[] memory _supports;
    {
      signatures = globalProposal.generateSignaturesGlobal(cheatGovernorPk.toSingletonArray(), Ballot.VoteType.For);
      _supports = new Ballot.VoteType[](signatures.length);

      vm.prank(cheatGovernor);
      manager.proposeGlobalProposalStructAndCastVotes(globalProposal, _supports, signatures);
    }

    // Check if the proposal is voted
    assertEq(manager.globalProposalVoted(globalProposal.nonce, cheatGovernor), true);
    for (uint256 i; i < _addingGovernors.length; ++i) {
      assertEq(manager.isBridgeOperator(_addingOperators[i]), true, "isBridgeOperator == false");
    }

    {
      TNetwork currentNetwork = CONFIG.getCurrentNetwork();
      (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();

      CONFIG.createFork(companionNetwork);
      CONFIG.switchTo(companionNetwork);

      MainchainBridgeManager mainchainManager = MainchainBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));

      uint256 snapshotId = vm.snapshot();

      cheatAddOverWeightedGovernor(address(mainchainManager));

      vm.prank(cheatGovernor);
      mainchainManager.relayGlobalProposal(globalProposal, _supports, signatures);

      for (uint256 i; i < _addingGovernors.length; ++i) {
        assertEq(mainchainManager.isBridgeOperator(_addingOperators[i]), true, "isBridgeOperator == false");
      }

      bool reverted = vm.revertTo(snapshotId);
      assertTrue(reverted, "Cannot revert to snapshot id");
      CONFIG.switchTo(currentNetwork);
    }
  }

  function validate_canExecuteUpgradeSingleProposal() private onlyOnRoninNetworkOrLocal onPostCheck("validate_canExecuteUpgradeSingleProposal") {
    TContract[] memory contractTypes = new TContract[](4);
    contractTypes[0] = Contract.BridgeSlash.key();
    contractTypes[1] = Contract.BridgeReward.key();
    contractTypes[2] = Contract.BridgeTracking.key();
    contractTypes[3] = Contract.RoninGatewayV3.key();

    address[] memory targets = new address[](contractTypes.length);
    for (uint256 i; i < contractTypes.length; ++i) {
      targets[i] = loadContract(contractTypes[i]);
    }

    for (uint256 i; i < targets.length; ++i) {
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractTypes[i]);
    }
  }

  function validate_canExcuteUpgradeAllOneProposal() private onlyOnRoninNetworkOrLocal onPostCheck("validate_canExcuteUpgradeAllOneProposal") {
    RoninBridgeManager manager = RoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    TContract[] memory contractTypes = new TContract[](5);
    contractTypes[0] = Contract.BridgeSlash.key();
    contractTypes[1] = Contract.BridgeReward.key();
    contractTypes[2] = Contract.BridgeTracking.key();
    contractTypes[3] = Contract.RoninGatewayV3.key();
    contractTypes[4] = Contract.RoninPauseEnforcer.key();

    address[] memory targets = new address[](contractTypes.length);
    for (uint256 i; i < contractTypes.length; ++i) {
      targets[i] = loadContract(contractTypes[i]);
    }

    address[] memory logics = new address[](targets.length);
    for (uint256 i; i < targets.length; ++i) {
      console.log("Deploy contract logic:", vm.getLabel(targets[i]));
      logics[i] = _deployLogic(contractTypes[i]);
    }

    // Upgrade all contracts with proposal
    bytes[] memory calldatas = new bytes[](targets.length);
    for (uint256 i; i < targets.length; ++i) {
      calldatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));
    }

    Proposal.ProposalDetail memory proposal = LibProposal.createProposal({
      manager: address(manager),
      expiryTimestamp: block.timestamp + 20 minutes,
      targets: targets,
      values: uint256(0).repeat(targets.length),
      calldatas: calldatas,
      gasAmounts: uint256(1_000_000).repeat(targets.length),
      nonce: manager.round(block.chainid) + 1
    });

    manager.executeProposal(proposal);
  }
}
