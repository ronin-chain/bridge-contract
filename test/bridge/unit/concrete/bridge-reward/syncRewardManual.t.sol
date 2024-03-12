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
import { MockBridgeManager } from "@ronin/test/mocks/MockBridgeManager.sol";

import { BridgeReward_Unit_Concrete_Test } from "./BridgeReward.t.sol";

contract SyncRewardManual_Unit_Concrete_Test is
  BridgeReward_Unit_Concrete_Test,
  IBridgeRewardEvents,
  BridgeTrackingHelper // Need to inherits this to access event
{
  function setUp() public virtual override {
    BridgeReward_Unit_Concrete_Test.setUp();
    MockBridgeManager(address(_bridgeManager)).addOperator({ governor: _governor, operator: _operator, weight: 100 });
    vm.startPrank({ msgSender: address(_operator) });
  }

  function test_RevertWhen_NotCalledByBridgeOperator() external {
    vm.stopPrank();
    vm.startPrank(_users.alice);
    vm.expectRevert(abi.encodeWithSelector(ErrUnauthorizedCall.selector, IBridgeReward.syncRewardManual.selector));
    _bridgeReward.syncRewardManual({ periodCount: 1 });
  }

  function test_RevertWhen_PeriodTooFar() public {
    uint256 currPd = _validatorSetContract.currentPeriod();
    uint256 lastRewardPd = currPd - 2;

    vm.expectRevert(abi.encodeWithSelector(ErrPeriodNotHappen.selector, currPd, lastRewardPd, 2));
    _bridgeReward.syncRewardManual({ periodCount: 2 });
  }

  function test_syncRewardManual_ShareProportionally() public {
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

    _bridgeReward.syncRewardManual({ periodCount: 1 });
    assertEq(_bridgeReward.getLatestRewardedPeriod(), settlePd);
  }
}
