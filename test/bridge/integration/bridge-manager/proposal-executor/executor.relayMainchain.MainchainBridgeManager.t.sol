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

contract ProposalWithExecutor_MainchainProposal_MainchainBridgeManager_Test is BaseIntegration_Test {
  event ProposalVoted(bytes32 indexed proposalHash, address indexed voter, Ballot.VoteType support, uint256 weight);
  event ProposalApproved(bytes32 indexed proposalHash);
  event ProposalExecuted(bytes32 indexed proposalHash, bool[] successCalls, bytes[] returnDatas);

  error ErrNonExecutorCannotRelay(address executor, address caller);
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

  Proposal.ProposalDetail _proposal;
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

    _proposal.nonce = _mainchainBridgeManager.round(block.chainid) + 1;
    _proposal.chainId = block.chainid;
    _proposal.executor = address(0);
    _proposal.expiryTimestamp = block.timestamp + _proposalExpiryDuration;

    _proposal.targets.push(address(_mainchainBridgeManager)); // Test Relay
    _proposal.values.push(0);
    _proposal.calldatas.push(abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)));
    _proposal.gasAmounts.push(1_000_000);

    // Duplicate the internal call
    _proposal.targets.push(address(_mainchainBridgeManager)); // Test Relay
    _proposal.values.push(0);
    _proposal.calldatas.push(abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)));
    _proposal.gasAmounts.push(1_000_000);
  }

  // Should the proposal is approved but not executed on Ronin chain
  function test_relayMainchain_autoProposal_looseProposal() public {
    _proposal.executor = address(0);

    vm.expectEmit(false, false, false, false);
    emit ProposalApproved(_anyValue);
    vm.expectEmit(false, false, false, false);
    emit ProposalExecuted(_anyValue, new bool[](2), new bytes[](2));

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignatures(_proposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    // Mainchain proposal take effect on Mainchain
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _beforeRelayedOperators);
    vm.prank(_param.roninBridgeManager.governors[0]);
    _mainchainBridgeManager.relayProposal(_proposal, _supports, _signatures);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should the non-auto proposal be relay by the specified executor
  function test_relayMainchain_executorProposal_looseProposal_WhenAllInternalCallsPass() public {
    _proposal.executor = _param.roninBridgeManager.governors[0];
    _proposal.gasAmounts[1] = 1_000_000; // Set gas for the second call becomes success

    vm.expectEmit(false, false, false, false);
    emit ProposalApproved(_anyValue);
    vm.expectEmit(false, false, false, false);
    emit ProposalExecuted(_anyValue, new bool[](2), new bytes[](2));

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignatures(_proposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    // Mainchain proposal take effect on Mainchain
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _beforeRelayedOperators);
    vm.prank(_param.roninBridgeManager.governors[0]);
    _mainchainBridgeManager.relayProposal(_proposal, _supports, _signatures);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should the non-auto proposal can not be execute by other governor
  function test_relayMainchain_executorProposal_revertWhen_proposalIsExecutedByAnotherGovernor() external {
    _proposal.executor = _param.roninBridgeManager.governors[0];
    _proposal.gasAmounts[1] = 1_000_000; // Set gas for the second call becomes success

    SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignatures(_proposal, _param.test.governorPKs);
    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.expectRevert(abi.encodeWithSelector(ErrNonExecutorCannotRelay.selector, _param.roninBridgeManager.governors[0], _param.roninBridgeManager.governors[1]));
    vm.prank(_param.roninBridgeManager.governors[1]);
    _mainchainBridgeManager.relayProposal(_proposal, _supports, _signatures);
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
