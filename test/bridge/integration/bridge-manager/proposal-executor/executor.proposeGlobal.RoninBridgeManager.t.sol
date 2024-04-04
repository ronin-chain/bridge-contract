// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import "../../BaseIntegration.t.sol";

contract ProposalWithExecutor_GlobalProposal_RoninBridgeManager_Test is BaseIntegration_Test {
  event ProposalVoted(bytes32 indexed proposalHash, address indexed voter, Ballot.VoteType support, uint256 weight);
  event ProposalApproved(bytes32 indexed proposalHash);
  event ProposalExecuted(bytes32 indexed proposalHash, bool[] successCalls, bytes[] returnDatas);

  error ErrInvalidExecutor();
  error ErrProposalNotApproved();
  error ErrInvalidProposalNonce(bytes4 sig);
  error ErrLooseProposalInternallyRevert(uint, bytes);

  using LibSort for address[];

  uint256 _proposalExpiryDuration;
  uint256 _addingOperatorNum;
  address[] _addingOperators;
  address[] _addingGovernors;
  uint96[] _voteWeights;

  address[] _beforeRelayedOperators;
  address[] _beforeRelayedGovernors;

  address[] _afterRelayedOperators;
  address[] _afterRelayedGovernors;

  Ballot.VoteType[] _supports;

  GlobalProposal.GlobalProposalDetail _globalProposal;
  SignatureConsumer.Signature[] _signatures;

  bytes32 _anyValue;

  function setUp() public virtual override {
    super.setUp();

    _proposalExpiryDuration = 60;
    _addingOperatorNum = 3;

    _beforeRelayedOperators = _param.roninBridgeManager.bridgeOperators;
    _beforeRelayedGovernors = _param.roninBridgeManager.governors;

    _supports = new Ballot.VoteType[](_beforeRelayedOperators.length);
    for (uint256 i; i < _beforeRelayedGovernors.length; i++) {
      _supports[i] = Ballot.VoteType.For;
    }

    _generateAddingOperators(_addingOperatorNum);

    _globalProposal.nonce = _roninBridgeManager.round(0) + 1;
    _globalProposal.executor = address(0);
    _globalProposal.expiryTimestamp = block.timestamp + _proposalExpiryDuration;

    _globalProposal.targetOptions.push(GlobalProposal.TargetOption.BridgeManager);
    _globalProposal.values.push(0);
    _globalProposal.calldatas.push(abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)));
    _globalProposal.gasAmounts.push(1_000_000);

    // Duplicate the internal call
    _globalProposal.targetOptions.push(GlobalProposal.TargetOption.BridgeManager);
    _globalProposal.values.push(0);
    _globalProposal.calldatas.push(abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)));
    _globalProposal.gasAmounts.push(1_000_000);
  }

  // Should the auto proposal executes on the last valid vote
  function test_autoProposal_strictProposal_WhenAllInternalCallsPass() public {
    _globalProposal.executor = address(0);

    vm.expectEmit(false, true, true, true);
    emit ProposalVoted(_anyValue, _param.roninBridgeManager.governors[0], Ballot.VoteType.For, 100);
    vm.expectEmit(false, false, false, false);
    emit ProposalApproved(_anyValue);
    vm.expectEmit(false, false, false, false);
    emit ProposalExecuted(_anyValue, new bool[](2), new bytes[](2));

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignaturesGlobal(_globalProposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(_globalProposal, _supports, _signatures);

    assertEq(_roninBridgeManager.globalProposalVoted(_globalProposal.nonce, _param.roninBridgeManager.governors[0]), true);
    assertEq(_roninBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should revert when the non-auto proposal get executed again
  function test_autoProposal_revertWhen_proposalIsAlreadyExecuted() external {
    test_autoProposal_strictProposal_WhenAllInternalCallsPass();

    vm.expectRevert(abi.encodeWithSelector(ErrProposalNotApproved.selector));

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.executeGlobal(_globalProposal);
  }

  // Should the non-auto proposal be execute by the specified executor
  function test_executorProposal_strictProposal_WhenAllInternalCallsPass() public {
    _globalProposal.executor = _param.roninBridgeManager.governors[0];
    _globalProposal.gasAmounts[1] = 1_000_000; // Set gas for the second call becomes success

    vm.expectEmit(false, true, true, true);
    emit ProposalVoted(_anyValue, _param.roninBridgeManager.governors[0], Ballot.VoteType.For, 100);
    vm.expectEmit(false, false, false, false);
    emit ProposalApproved(_anyValue);

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignaturesGlobal(_globalProposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(_globalProposal, _supports, _signatures);
    assertEq(_roninBridgeManager.globalProposalVoted(_globalProposal.nonce, _param.roninBridgeManager.governors[0]), true);
    assertEq(_roninBridgeManager.getBridgeOperators(), _beforeRelayedOperators);

    vm.expectEmit(false, false, false, false);
    emit ProposalExecuted(_anyValue, new bool[](2), new bytes[](2));

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.executeGlobal(_globalProposal);
    assertEq(_roninBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should revert when the auto proposal get executed again
  function test_executorProposal_revertWhen_proposalIsAlreadyExecuted() external {
    test_executorProposal_strictProposal_WhenAllInternalCallsPass();

    vm.expectRevert(abi.encodeWithSelector(ErrProposalNotApproved.selector));

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.executeGlobal(_globalProposal);
  }

  // Should the non-auto proposal can not be execute by other governor
  function test_executorProposal_revertWhen_proposalIsExecutedByAnotherGovernor() external {
    _globalProposal.executor = _param.roninBridgeManager.governors[0];
    _globalProposal.gasAmounts[1] = 1_000_000; // Set gas for the second call becomes success

    vm.expectEmit(false, true, true, true);
    emit ProposalVoted(_anyValue, _param.roninBridgeManager.governors[0], Ballot.VoteType.For, 100);
    vm.expectEmit(false, false, false, false);
    emit ProposalApproved(_anyValue);

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignaturesGlobal(_globalProposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(_globalProposal, _supports, _signatures);
    assertEq(_roninBridgeManager.globalProposalVoted(_globalProposal.nonce, _param.roninBridgeManager.governors[0]), true);
    assertEq(_roninBridgeManager.getBridgeOperators(), _beforeRelayedOperators);

    vm.expectRevert(abi.encodeWithSelector(ErrInvalidExecutor.selector));
    vm.prank(_param.roninBridgeManager.governors[1]);
    _roninBridgeManager.executeGlobal(_globalProposal);
  }

  function _generateAddingOperators(uint256 num) internal {
    delete _addingOperators;
    delete _addingGovernors;
    delete _voteWeights;

    _afterRelayedOperators = _beforeRelayedOperators;
    _afterRelayedGovernors = _beforeRelayedGovernors;

    for (uint256 i; i < num; i++) {
      _addingOperators.push(makeAddr(string.concat("adding-operator", vm.toString(i))));
      _addingGovernors.push(makeAddr(string.concat("adding-governor", vm.toString(i))));
      _voteWeights.push(uint96(uint256(100)));

      _afterRelayedOperators.push(_addingOperators[i]);
      _afterRelayedGovernors.push(_addingGovernors[i]);
    }
  }
}
