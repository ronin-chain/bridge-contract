// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { BasePostCheck } from "script/post-check/BasePostCheck.s.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";

/**
 * @title PostCheck_BridgeManager_CRUD_AddBridgeOperators
 * @dev This contract contains post-check functions for adding bridge operators in the BridgeManager contract.
 */
abstract contract PostCheck_BridgeManager_CRUD_AddBridgeOperators is BasePostCheck {
  using LibArray for *;

  uint256 private voteWeight = 100;
  string private seedStr = vm.toString(seed);
  address private any = makeAddr(string.concat("any", seedStr));
  address private operator = makeAddr(string.concat("operator-", seedStr));
  address private governor = makeAddr(string.concat("governor-", seedStr));

  function _validate_BridgeManager_CRUD_addBridgeOperators() internal {
    validate_RevertWhen_NotSelfCalled_addBridgeOperators();
    validate_RevertWhen_SelfCalled_TheListHasDuplicate_addBridgeOperators();
    validate_RevertWhen_SelfCalled_InputArrayLengthMismatch_addBridgeOperators();
    validate_RevertWhen_SelfCalled_ContainsNullVoteWeight_addBridgeOperators();
    validate_addBridgeOperators();
  }

  /**
   * @dev Validates that the function `addBridgeOperators` reverts when it is not self-called.
   */
  function validate_RevertWhen_NotSelfCalled_addBridgeOperators() private onPostCheck("validate_RevertWhen_NotSelfCalled_addBridgeOperators") {
    vm.expectRevert();
    vm.prank(any);
    bool[] memory addeds = IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      voteWeight.toSingletonArray().toUint96sUnsafe(), operator.toSingletonArray(), governor.toSingletonArray()
    );
  }

  /**
   * @dev Validates that the function `addBridgeOperators` reverts when the list of operators contains duplicates.
   */
  function validate_RevertWhen_SelfCalled_TheListHasDuplicate_addBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_TheListHasDuplicate_addBridgeOperators")
  {
    vm.expectRevert();
    vm.prank(_manager[block.chainid]);
    bool[] memory addeds = IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      voteWeight.toSingletonArray().toUint96sUnsafe(), operator.toSingletonArray(), operator.toSingletonArray()
    );

    vm.expectRevert();
    vm.prank(_manager[block.chainid]);
    addeds = IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      voteWeight.toSingletonArray().toUint96sUnsafe(), governor.toSingletonArray(), governor.toSingletonArray()
    );

    vm.expectRevert();
    vm.prank(_manager[block.chainid]);
    addeds = IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      voteWeight.toSingletonArray().toUint96sUnsafe(),
      governor.toSingletonArray().extend(operator.toSingletonArray()),
      operator.toSingletonArray().extend(governor.toSingletonArray())
    );
  }

  /**
   * @dev Validates that the function `addBridgeOperators` reverts when the input array lengths mismatch.
   */
  function validate_RevertWhen_SelfCalled_InputArrayLengthMismatch_addBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_InputArrayLengthMismatch_addBridgeOperators")
  {
    vm.prank(_manager[block.chainid]);
    vm.expectRevert();
    IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      voteWeight.toSingletonArray().toUint96sUnsafe(), governor.toSingletonArray(), operator.toSingletonArray().extend(governor.toSingletonArray())
    );
  }

  /**
   * @dev Validates that the function `addBridgeOperators` reverts when the input array contains a null vote weight.
   */
  function validate_RevertWhen_SelfCalled_ContainsNullVoteWeight_addBridgeOperators()
    private
    onPostCheck("validate_RevertWhen_SelfCalled_ContainsNullVoteWeight_addBridgeOperators")
  {
    vm.prank(_manager[block.chainid]);
    vm.expectRevert();
    IBridgeManager(_manager[block.chainid]).addBridgeOperators(
      uint256(0).toSingletonArray().toUint96sUnsafe(), governor.toSingletonArray(), operator.toSingletonArray().extend(governor.toSingletonArray())
    );
  }

  /**
   * @dev Validates that the function `addBridgeOperators`.
   */
  function validate_addBridgeOperators() private onPostCheck("validate_addBridgeOperators") {
    address manager = _manager[block.chainid];
    uint256 totalWeightBefore = IBridgeManager(manager).getTotalWeight();
    uint256 totalBridgeOperatorsBefore = IBridgeManager(manager).getBridgeOperators().length;

    vm.prank(manager);
    bool[] memory addeds =
      IBridgeManager(manager).addBridgeOperators(voteWeight.toSingletonArray().toUint96sUnsafe(), governor.toSingletonArray(), operator.toSingletonArray());

    assertTrue(addeds[0], "addeds[0] == false");
    assertTrue(IBridgeManager(manager).isBridgeOperator(operator), "isBridgeOperator(operator) == false");
    assertEq(IBridgeManager(manager).getTotalWeight(), totalWeightBefore + voteWeight, "getTotalWeight() != totalWeightBefore + voteWeight");
    assertEq(
      IBridgeManager(manager).getBridgeOperators().length, totalBridgeOperatorsBefore + 1, "getBridgeOperators().length != totalBridgeOperatorsBefore + 1"
    );
    // Deprecated
    // assertEq(IBridgeManager(manager).getGovernorsOf(operator.toSingletonArray())[0], governor, "getGovernorsOf(operator)[0] != governor");
    // Deprecated
    // assertEq(IBridgeManager(manager).getBridgeOperatorOf(governor.toSingletonArray())[0], operator, "getBridgeOperatorOf(governor)[0] != operator");
  }
}
