// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { MockGatewayForTracking } from "@ronin/contracts/mocks/MockGatewayForTracking.sol";
import "../BaseIntegration.t.sol";

// Epoch e-2 test: Vote is approved NOT in the last epoch
contract EpochE2_VoteIsNotApprovedInLastEpoch_BridgeTracking_Test is BaseIntegration_Test {
  MockGatewayForTracking _mockRoninGatewayV3;

  uint256 _period;
  uint256 _receiptId;
  IBridgeTracking.VoteKind _receiptKind;
  address[] _operators;

  function setUp() public virtual override {
    super.setUp();

    vm.coinbase(makeAddr("coin-base-addr"));

    // upgrade ronin gateway v3
    _mockRoninGatewayV3 = new MockGatewayForTracking(address(_bridgeTracking));

    bytes memory calldata_ =
      abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE, address(_mockRoninGatewayV3)));
    _roninProposalUtils.functionDelegateCall(address(_bridgeTracking), calldata_);

    vm.deal(address(_bridgeReward), 10 ether);

    // _moveToEndPeriodAndWrapUpEpoch();

    _period = _validatorSet.currentPeriod();
    _receiptId = 0;
    _receiptKind = IBridgeTracking.VoteKind.Deposit;

    _operators.push(_param.roninBridgeManager.bridgeOperators[0]);
    _operators.push(_param.roninBridgeManager.bridgeOperators[1]);
  }

  // Epoch e-2: Vote & Approve & Vote. > Should not record the receipts which is not approved yet
  function test_epochE2_notRecordVoteAndBallot_receiptWithoutApproval() public {
    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, _operators);

    assertEq(_bridgeTracking.totalVote(_period), 0);
    assertEq(_bridgeTracking.totalBallot(_period), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), 0);
  }

  // Epoch e-2: Vote & Approve & Vote. > Should be able to approve the receipts and Should not record the approved receipts once the epoch is not yet wrapped up
  function test_epochE2_recordVoteAndBallot_receiptIsApproved() public {
    test_epochE2_notRecordVoteAndBallot_receiptWithoutApproval();

    _mockRoninGatewayV3.sendApprovedVote(_receiptKind, _receiptId);
    assertEq(_bridgeTracking.totalVote(_period), 0);
    assertEq(_bridgeTracking.totalBallot(_period), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), 0);
  }

  // Epoch e-1: Continue voting for the vote of e-2 > Should be able to record the approved votes/ballots when the epoch is wrapped up (value from buffer metric)
  function test_epochE1_continueVotingForVoteOfE2() public {
    test_epochE2_recordVoteAndBallot_receiptIsApproved();

    _wrapUpEpochAndMine();

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 2);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
  }

  // Epoch e-1: Continue voting for the vote of e-2 > Should be able to record the approved votes/ballots when the epoch is wrapped up
  function test_epochE1_recordForWhoVoteLately_onceRequestIsApproved() public {
    test_epochE1_continueVotingForVoteOfE2();

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[2]));

    _wrapUpEpochAndMine();
    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(_period), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(_period), expectedTotalVotes * 3);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallotOf(_period, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes);
  }

  // Epoch e (first epoch of new period): Continue voting for vote in e-2 > Should not record in the next period
  function test_epochE_continueVotingForVoteInE2_notRecordInNextPeriod() public {
    test_epochE1_recordForWhoVoteLately_onceRequestIsApproved();

    _moveToEndPeriodAndWrapUpEpoch();

    uint256 lastPeriod = _period;
    uint256 newPeriod = _validatorSet.currentPeriod();
    assertTrue(newPeriod != lastPeriod);

    _mockRoninGatewayV3.sendBallot(_receiptKind, _receiptId, wrapAddress(_param.roninBridgeManager.bridgeOperators[3]));

    uint256 expectedTotalVotes = 1;
    assertEq(_bridgeTracking.totalVote(lastPeriod), expectedTotalVotes);
    assertEq(_bridgeTracking.totalBallot(lastPeriod), expectedTotalVotes * 3);
    assertEq(
      _bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[0]), expectedTotalVotes
    );
    assertEq(
      _bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[1]), expectedTotalVotes
    );
    assertEq(
      _bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[2]), expectedTotalVotes
    );
    assertEq(_bridgeTracking.totalBallotOf(lastPeriod, _param.roninBridgeManager.bridgeOperators[3]), 0);

    _period = newPeriod;

    assertEq(_bridgeTracking.totalVote(newPeriod), 0);
    assertEq(_bridgeTracking.totalBallot(newPeriod), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[0]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[1]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[2]), 0);
    assertEq(_bridgeTracking.totalBallotOf(newPeriod, _param.roninBridgeManager.bridgeOperators[3]), 0);
  }
}
