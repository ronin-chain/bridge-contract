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

import { BridgeReward_Unit_Concrete_Test } from "./BridgeReward_Unit_Concrete.t.sol";

contract ExecSyncRewardAuto_Unit_Concrete_Test is
  BridgeReward_Unit_Concrete_Test,
  IBridgeRewardEvents,
  BridgeTrackingHelper // Need to inherits this to access event
{
  function setUp() public virtual override {
    BridgeReward_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeTracking) });
  }

  function test_RevertWhen_NotCalledByBridgeTracking() external {
    uint256 period = _validatorSetContract.currentPeriod() + 1;

    changePrank(_users.alice);
    vm.expectRevert(
      abi.encodeWithSelector(ErrUnexpectedInternalCall.selector, IBridgeReward.execSyncRewardAuto.selector, ContractType.BRIDGE_TRACKING, _users.alice)
    );
    _bridgeReward.execSyncRewardAuto({ currentPeriod: period });
  }

  function test_syncRewardAuto_1Period_ShareProportionally() public {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 nowPd = _validatorSetContract.currentPeriod();
    uint256 settlePd = nowPd - 1;

    _bridgeManager.cheat_setOperators(operators);
    _bridgeTracking.cheat_setPeriodTracking(settlePd, operators, ballots, totalVote);
    _bridgeSlash.cheat_setSlash(operators, new uint256[](operators.length));

    for (uint i; i < operators.length; i++) {
      vm.expectEmit({ emitter: address(_bridgeReward) });
      emit BridgeRewardScattered(settlePd, operators[i], (_rewardPerPeriod * ballots[i]) / totalBallot);
    }

    _bridgeReward.execSyncRewardAuto({ currentPeriod: nowPd });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), settlePd);
  }

  function test_syncRewardAuto_3Period_ShareProportionally() public {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 pdGap = 3;
    uint256 pdCount = pdGap;

    uint256 period = _validatorSetContract.currentPeriod();
    uint256 nowPd = period + pdCount - 1;
    uint256 settlePd = period - 1;
    _validatorSetContract.setCurrentPeriod(nowPd);

    _bridgeManager.cheat_setOperators(operators);
    _bridgeSlash.cheat_setSlash(operators, new uint256[](operators.length));

    for (uint i; i < pdCount; i++) {
      _bridgeTracking.cheat_setPeriodTracking(settlePd + i, operators, ballots, totalVote);
    }

    for (uint i; i < pdCount; i++) {
      for (uint k; k < operators.length; k++) {
        vm.expectEmit({ emitter: address(_bridgeReward) });
        emit BridgeRewardScattered(settlePd + i, operators[k], (_rewardPerPeriod * ballots[k]) / totalBallot);
      }
    }

    _bridgeReward.execSyncRewardAuto({ currentPeriod: nowPd });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), settlePd + pdCount - 1);
  }

  function test_syncRewardAuto_MoreThan5Period_ShareProportionally() public {
    (address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote) = _generateInput_shareRewardProportionally();
    uint256 pdGap = 7;
    uint256 pdCount = 5;

    uint256 period = _validatorSetContract.currentPeriod();
    uint256 nowPd = period + pdGap - 1;
    uint256 settlePd = period - 1;
    _validatorSetContract.setCurrentPeriod(nowPd);

    _bridgeManager.cheat_setOperators(operators);
    _bridgeSlash.cheat_setSlash(operators, new uint256[](operators.length));

    for (uint i; i < pdGap; i++) {
      _bridgeTracking.cheat_setPeriodTracking(settlePd + i, operators, ballots, totalVote);
    }

    // Settle reward for first 5 periods
    for (uint i = 0; i < pdCount; i++) {
      for (uint k; k < operators.length; k++) {
        vm.expectEmit({ emitter: address(_bridgeReward) });
        emit BridgeRewardScattered(settlePd + i, operators[k], (_rewardPerPeriod * ballots[k]) / totalBallot);
      }
    }

    _bridgeReward.execSyncRewardAuto({ currentPeriod: nowPd });
    settlePd = settlePd + pdCount - 1;
    assertEq(_bridgeReward.getLatestRewardedPeriod(), settlePd);

    // Settle reward for the remaining periods
    pdGap -= pdCount;
    pdCount = pdGap;
    settlePd += 1;
    for (uint i; i < pdCount; i++) {
      for (uint k; k < operators.length; k++) {
        vm.expectEmit({ emitter: address(_bridgeReward) });
        emit BridgeRewardScattered(settlePd + i, operators[k], (_rewardPerPeriod * ballots[k]) / totalBallot);
      }
    }

    _bridgeReward.execSyncRewardAuto({ currentPeriod: nowPd });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), nowPd - 1);
  }
}
