// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { MockGatewayForTracking } from "@ronin/contracts/mocks/MockGatewayForTracking.sol";
import "../BaseIntegration.t.sol";

import { EpochE2_VoteIsNotApprovedInLastEpoch_BridgeTracking_Test } from
  "./EpochE2_VoteIsNotApprovedInLastEpoch.BridgeTracking.t.sol";

// Epoch e-1 test: Vote is approved in the last epoch of period
contract EpochE1_VoteIsApprovedInLastEpoch_BridgeTracking_Test is BaseIntegration_Test {
  MockGatewayForTracking _mockRoninGatewayV3;

  uint256 _period;
  uint256 _receiptId;
  IBridgeTracking.VoteKind _receiptKind;
  address[] _operators;

  function setUp() public virtual override {
    super.setUp();

    vm.coinbase(makeAddr("coin-base-addr"));

    _operators.push(_param.roninBridgeManager.bridgeOperators[0]);
    _operators.push(_param.roninBridgeManager.bridgeOperators[1]);
    _receiptId = 1;
    _receiptKind = IBridgeTracking.VoteKind.Withdrawal;

    // upgrade ronin gateway v3
    _mockRoninGatewayV3 = new MockGatewayForTracking(address(_bridgeTracking));

    bytes memory calldata_ =
      abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE, address(_mockRoninGatewayV3)));
    _roninProposalUtils.functionDelegateCall(address(_bridgeTracking), calldata_);

    vm.deal(address(_bridgeReward), 10 ether);

    _moveToEndPeriodAndWrapUpEpoch();
    _period = _validatorSet.currentPeriod();
  }

  // Epoch e-1: Vote & Approve & Vote > Should not record when not approved yet. Vote in last epoch (e-1).
  function test_epochEMinus1_notRecordVoteAndBallot_receiptWithoutApproval() public {
    _wrapUpEpoch();
    _wrapUpEpoch();
    _wrapUpEpoch();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, _operators);

    assertEq(_bridgeTracking.totalVote(_period), 0);
    assertEq(_bridgeTracking.totalBallot(_period), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), 0);
  }

  // Epoch e-1: Vote & Approve & Vote > Should not record when approve. Approve in last epoch (e-1).
  function test_epochEMinus1_notRecordVoteAndBallot_approveInLastEpoch() public {
    test_epochEMinus1_notRecordVoteAndBallot_receiptWithoutApproval();

    _mockRoninGatewayV3.sendApprovedVote(_receiptKind, _receiptId);

    assertEq(_bridgeTracking.totalVote(_period), 0);
    assertEq(_bridgeTracking.totalBallot(_period), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), 0);
  }

  // Epoch e-1: Vote & Approve & Vote > Should not record even after approved. Vote in last epoch (e-1).
  function test_epochEMinus1_notRecordVoteAndBallot_voteInLastEpoch() public {
    test_epochEMinus1_notRecordVoteAndBallot_approveInLastEpoch();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[2]));

    assertEq(_bridgeTracking.totalVote(_period), 0);
    assertEq(_bridgeTracking.totalBallot(_period), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), 0);
  }

  // Epoch e: vote > Should not record for current period metric when wrapping up period. Query in next epoch (e), for current period (p-1): return 0.
  function test_epochE_notRecordForCurrentPeriod_WhenWrappingUpPeriod() public {
    test_epochEMinus1_notRecordVoteAndBallot_voteInLastEpoch();

    uint256 lastPeriod = _period;
    _moveToEndPeriodAndWrapUpEpoch();

    uint256 newPeriod = _validatorSet.currentPeriod();
    _period = newPeriod;
    assertEq(newPeriod, lastPeriod + 1);

    assertEq(_bridgeTracking.totalVote(lastPeriod), 0);
    assertEq(_bridgeTracking.totalBallot(lastPeriod), 0);
    assertEq(_bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[1]), 0);
    assertEq(_bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[2]), 0);
  }

  // Epoch e: vote > Should record for the buffer metric when wrapping up period. Query in next epoch (e), for next period (p): return >0 (buffer).
  function test_epochE_recordBufferMetricForNewPeriod_WhenWrappingUpPeriod() public {
    test_epochE_notRecordForCurrentPeriod_WhenWrappingUpPeriod();

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 3);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
  }

  // Epoch e: vote > Should record new ballot for the buffer metric
  function test_epochE_recordNewBallotForBufferMetric() public {
    test_epochE_recordBufferMetricForNewPeriod_WhenWrappingUpPeriod();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[3]));

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 4);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[3]), expectedTotalVotes);

    _wrapUpEpochAndMine();

    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 4);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[3]), expectedTotalVotes);
  }

  // Epoch 2e-1: vote > Should record new ballot for the buffer metric
  function test_epoch2EMinus1_recordNewBallotForBufferMetric() public {
    test_epochE_recordNewBallotForBufferMetric();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[4]));

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 5);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[3]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[4]), expectedTotalVotes);

    _moveToEndPeriodAndWrapUpEpoch();

    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 5);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[3]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[4]), expectedTotalVotes);
  }

  // Epoch 3e: vote > Should not record new ballot. And the period metric is finalized as in epoch 2e-1.
  function test_epoch3E_notRecordNewBallot_periodMetricIsFinalizedAsInepoch2EMinus1() public {
    test_epoch2EMinus1_recordNewBallotForBufferMetric();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[5]));

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 5);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[3]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[4]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[5]), 0);
  }

  // Epoch 3e: vote > Should the metric of the new period get reset.
  function test_epoch3E_metricOfNewPeriodGetReset() public {
    test_epoch3E_notRecordNewBallot_periodMetricIsFinalizedAsInepoch2EMinus1();

    _moveToEndPeriodAndWrapUpEpoch();

    uint256 lastPeriod = _period;
    uint256 newPeriod = _validatorSet.currentPeriod();
    _period = newPeriod;
    assertTrue(newPeriod != lastPeriod);

    assertEq(_bridgeTracking.totalVote(newPeriod), 0);
    assertEq(_bridgeTracking.totalBallot(newPeriod), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[1]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[2]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[3]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[4]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[5]), 0);
  }
}
