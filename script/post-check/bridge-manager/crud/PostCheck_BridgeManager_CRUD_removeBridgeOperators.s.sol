// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { BasePostCheck } from "script/post-check/BasePostCheck.s.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";

abstract contract PostCheck_BridgeManager_CRUD_RemoveBridgeOperators is BasePostCheck {
  using LibArray for *;

  string private seedStr = vm.toString(seed);
  address private operatorToRemove;
  uint256 private voteWeightToRemove;
  address private any = makeAddr(string.concat("any", seedStr));

  function _validate_BridgeManager_CRUD_removeBridgeOperators() internal {
    address manager = roninBridgeManager;
    address[] memory operators = IBridgeManager(manager).getBridgeOperators();
    uint256 idx = _bound(seed, 0, operators.length - 1);

    operatorToRemove = operators[idx];
    voteWeightToRemove = IBridgeManager(manager).getBridgeOperatorWeight(operatorToRemove);

    validate_RevertWhen_NotSelfCalled_removeBridgeOperators();
    validate_RevertWhen_SelfCalled_TheListHasDuplicate_removeBridgeOperators();
    validate_RevertWhen_SelfCalled_TheListHasNull_removeBridgeOperators();
    validate_RevertWhen_SelfCalled_RemovedOperatorIsNotInTheList_removeBridgeOperators();
    validate_removeBridgeOperators();
  }

  function validate_RevertWhen_NotSelfCalled_removeBridgeOperators() private onPostCheck("validate_RevertWhen_NotSelfCalled_removeBridgeOperators") {
    vm.prank(any);
    vm.expectRevert();
    TransparentUpgradeableProxyV2(payable(roninBridgeManager)).functionDelegateCall(
      abi.encodeCall(IBridgeManager.removeBridgeOperators, (operatorToRemove.toSingletonArray()))
    );
  }

  function validate_RevertWhen_SelfCalled_TheListHasDuplicate_removeBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_TheListHasDuplicate_removeBridgeOperators")
  {
    vm.prank(roninBridgeManager);
    vm.expectRevert();
    TransparentUpgradeableProxyV2(payable(roninBridgeManager)).functionDelegateCall(
      abi.encodeCall(IBridgeManager.removeBridgeOperators, (operatorToRemove.toSingletonArray().extend(operatorToRemove.toSingletonArray())))
    );
  }

  function validate_RevertWhen_SelfCalled_TheListHasNull_removeBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_TheListHasNull_removeBridgeOperators")
  {
    vm.prank(roninBridgeManager);
    vm.expectRevert();
    TransparentUpgradeableProxyV2(payable(roninBridgeManager)).functionDelegateCall(
      abi.encodeCall(IBridgeManager.removeBridgeOperators, (address(0).toSingletonArray()))
    );
  }

  function validate_RevertWhen_SelfCalled_RemovedOperatorIsNotInTheList_removeBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_RemovedOperatorIsNotInTheList_removeBridgeOperators")
  {
    vm.expectRevert();
    vm.prank(roninBridgeManager);
    TransparentUpgradeableProxyV2(payable(roninBridgeManager)).functionDelegateCall(
      abi.encodeCall(IBridgeManager.removeBridgeOperators, (any.toSingletonArray()))
    );
  }

  function validate_removeBridgeOperators() private onPostCheck("validate_removeBridgeOperators") {
    address manager = roninBridgeManager;
    uint256 total = IBridgeManager(manager).totalBridgeOperator();
    uint256 totalWeightBefore = IBridgeManager(manager).getTotalWeight();
    uint256 expected = total - 1;

    vm.prank(manager);
    TransparentUpgradeableProxyV2(payable(roninBridgeManager)).functionDelegateCall(
      abi.encodeCall(IBridgeManager.removeBridgeOperators, (operatorToRemove.toSingletonArray()))
    );
    uint256 actual = IBridgeManager(manager).totalBridgeOperator();

    assertEq(actual, expected, "Bridge operator is not removed");
    assertEq(IBridgeManager(manager).getTotalWeight(), totalWeightBefore - voteWeightToRemove, "Bridge operator is not removed");
    assertFalse(IBridgeManager(manager).isBridgeOperator(operatorToRemove), "Bridge operator is not removed");
    assertEq(IBridgeManager(manager).getBridgeOperatorWeight(operatorToRemove), 0, "Bridge operator is not removed");
    // Deprecated
    // assertEq(IBridgeManager(manager).getGovernorsOf(operatorToRemove.toSingletonArray()), address(0).toSingletonArray(), "Bridge operator is not removed");
  }
}
