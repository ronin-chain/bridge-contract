// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import "@ronin/contracts/utils/CommonErrors.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { IBridgeRewardEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeRewardEvents.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeTrackingHelper } from "@ronin/contracts/extensions/bridge-operator-governance/BridgeTrackingHelper.sol";

import "../BridgeReward_Unit_Concrete.t.sol";

contract SettleReward_Unit_Concrete_Test is
  BridgeReward_Unit_Concrete_Test,
  IBridgeRewardEvents,
  BridgeTrackingHelper // Need to inherits this to access event
{
  function setUp() public virtual override {
    BridgeReward_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeTracking) });
  }

  function test_RevertWhen_OperatorsLengthIsZero() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod() + 1;

    assembly ("memory-safe") {
      mstore(operators, 0)
      mstore(ballots, 0)
    }

    // TODO: test tx not emit event
    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
  }

  function test_RevertWhen_TwoInputArraysLengthsDiffer() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod() + 1;

    assembly ("memory-safe") {
      mstore(operators, 1)
    }

    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, BridgeRewardHarness.exposed_settleReward.selector));
    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });

    assembly ("memory-safe") {
      mstore(operators, 0)
    }

    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, BridgeRewardHarness.exposed_settleReward.selector));
    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
  }

  function test_settleReward_ShareEqually_WhenDataCorrupts_NotTopUpFund() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod();

    ballots[0] = 100_000;

    // Set balance of bridge reward to zero
    vm.deal({ account: address(_bridgeReward), newBalance: 0 });

    vm.expectEmit({ emitter: address(_bridgeReward) });
    emit BridgeTrackingIncorrectlyResponded();
    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScatterFailed(period, operators[i], _rewardPerPeriod / operators.length);
    }

    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });

    assertEq(_bridgeReward.getLatestRewardedPeriod(), period);
  }

  function test_settleReward_ShareEqually_WhenDataCorrupts_HaveEnoughFund_OneAbnormalBallot() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod();

    ballots[0] = 100_000;

    vm.expectEmit({ emitter: address(_bridgeReward) });
    emit BridgeTrackingIncorrectlyResponded();
    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScattered(period, operators[i], _rewardPerPeriod / operators.length);
    }

    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), period);
  }

  function test_settleReward_ShareEqually_WhenDataCorrupts_HaveEnoughFund_AbnormalTotalBallot() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod();

    // Reduce number of total ballot
    totalBallot -= 1;

    vm.expectEmit({ emitter: address(_bridgeReward) });
    emit BridgeTrackingIncorrectlyResponded();
    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScattered(period, operators[i], _rewardPerPeriod / operators.length);
    }

    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
  }

  function test_settleReward_ShareEqually_WhenNoVote() external {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod();

    ballots[0] = 0;
    ballots[1] = 0;
    ballots[2] = 0;
    ballots[3] = 0;
    totalBallot = 0;
    totalVote = 100;

    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScattered(period, operators[i], _rewardPerPeriod / operators.length);
    }

    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), period);
  }

  function test_settleReward_SharePropotionally() public {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 period = _validatorSetContract.currentPeriod();

    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScattered(period, operators[i], (_rewardPerPeriod * ballots[i]) / totalBallot);
    }

    _bridgeReward.exposed_settleReward({ operators: operators, ballots: ballots, totalBallot: totalBallot, totalVote: totalVote, period: period });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), period);
  }
}
