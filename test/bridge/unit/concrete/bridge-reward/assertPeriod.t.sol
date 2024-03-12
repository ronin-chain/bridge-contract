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

import "./BridgeReward.t.sol";

contract AssertPeriod_Unit_Concrete_Test is
  BridgeReward_Unit_Concrete_Test,
  IBridgeRewardEvents,
  BridgeTrackingHelper // Need to inherits this to access event
{
  function setUp() public virtual override {
    BridgeReward_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeTracking) });
  }

  function test_RevertWhen_assertPeriod_PeriodCountIsZero() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodCountIsZero.selector));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 1, pdCount: 0, currPd: 1 });
  }

  function test_RevertWhen_assertPeriod_PeriodIsAlreadyRewarded() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodAlreadyRewarded.selector, 38, 37));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 37, pdCount: 1, currPd: 38 });
  }

  function test_RevertWhen_assertPeriod_PeriodIsAlreadyRewarded_Multi() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodAlreadyRewarded.selector, 37, 37));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 37, pdCount: 2, currPd: 37 });
  }

  function test_RevertWhen_assertPeriod_PeriodIsAlreadyRewarded_LongAgo() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodAlreadyRewarded.selector, 30, 37));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 37, pdCount: 2, currPd: 30 });
  }

  function test_RevertWhen_assertPeriod_PeriodNotHappen_1() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodNotHappen.selector, 37, 35, 2));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 35, pdCount: 2, currPd: 37 });
  }

  function test_RevertWhen_assertPeriod_PeriodNotHappen_2() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodNotHappen.selector, 37, 34, 3));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 34, pdCount: 3, currPd: 37 });
  }

  function test_RevertWhen_assertPeriod_PeriodNotHappen_CountTooBig() external {
    vm.expectRevert(abi.encodeWithSelector(ErrPeriodNotHappen.selector, 37, 34, 3000000));
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 34, pdCount: 3000000, currPd: 37 });
  }

  function test_assertPeriod_Passed_WhenRequest1CurrentPeriod_UpToCurrent() external view {
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 35, pdCount: 1, currPd: 37 });
  }

  function test_assertPeriod_Passed_WhenRequest2CurrentPeriod_UpToCurrent() external view {
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 34, pdCount: 2, currPd: 37 });
  }

  function test_assertPeriod_Passed_WhenRequest1CurrentPeriod_NotUpToCurrent() external view {
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 34, pdCount: 1, currPd: 37 });
  }

  function test_assertPeriod_Passed_WhenRequest3CurrentPeriod_NotUpToCurrent() external view {
    _bridgeReward.exposed_assertPeriod({ lastRewardPd: 33, pdCount: 3, currPd: 37 });
  }
}
