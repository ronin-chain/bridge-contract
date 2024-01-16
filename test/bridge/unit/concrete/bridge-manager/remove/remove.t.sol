// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import { LibArrayUtils } from "@ronin/test/helpers/LibArrayUtils.t.sol";

import "@ronin/contracts/utils/CommonErrors.sol";
import { AddressArrayUtils } from "@ronin/contracts/libraries/AddressArrayUtils.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

import { BridgeManager_Unit_Concrete_Test } from "../BridgeManager.t.sol";

contract Remove_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  function setUp() public virtual override {
    BridgeManager_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeManager) });
  }

  function test_RevertWhen_NotSelfCall() external {
    // Prepare data
    (address[] memory removingOperators, , , , , ) = _generateRemovingOperators(1);

    // Make the caller not self-call.
    changePrank({ msgSender: _bridgeOperators[0] });

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrOnlySelfCall.selector, IBridgeManager.removeBridgeOperators.selector));
    _bridgeManager.removeBridgeOperators(removingOperators);
  }

  function test_RevertWhen_RemoveOperator_OneAddress_AddressNotOperator() external {
    address[] memory removingOperators = wrapAddress(_governors[0]);

    vm.expectRevert(abi.encodeWithSelector(IBridgeManager.ErrOperatorNotFound.selector, removingOperators[0]));
    _bridgeManager.removeBridgeOperators(removingOperators);
  }

  function test_RemoveOperators_OneAddress_ThatValid() external {
    (
      address[] memory removingOperators,
      address[] memory removingGovernors,
      uint96[] memory removingWeights,
      address[] memory remainingOperators,
      address[] memory remainingGovernors,
      uint96[] memory remainingWeights
    ) = _generateRemovingOperators(1);

    bool[] memory removeds = _bridgeManager.removeBridgeOperators(removingOperators);
    bool[] memory expectedRemoved = new bool[](1);
    expectedRemoved[0] = true;
    assertEq(removeds, expectedRemoved);

    assertEq(_bridgeManager.totalBridgeOperator(), _bridgeOperators.length - 1, "wrong total bridge operator");
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight - removingWeights[0], "wrong total total weight");

    vm.expectRevert(abi.encodeWithSelector(IBridgeManager.ErrGovernorNotFound.selector, removingGovernors[0]));
    _bridgeManager.getOperatorOf(removingGovernors[0]);

    vm.expectRevert(abi.encodeWithSelector(IBridgeManager.ErrOperatorNotFound.selector, removingOperators[0]));
    _bridgeManager.getGovernorOf(removingOperators[0]);

    // Compare after and before state
    (address[] memory afterBridgeOperators, address[] memory afterGovernors, uint96[] memory afterVoteWeights) = _getBridgeMembersByGovernors(
      remainingGovernors
    );

    _assertBridgeMembers({
      comparingOperators: afterBridgeOperators,
      comparingGovernors: afterGovernors,
      comparingWeights: afterVoteWeights,
      expectingOperators: remainingOperators,
      expectingGovernors: remainingGovernors,
      expectingWeights: remainingWeights
    });
  }

  function test_RevertWhen_TwoAddress_Duplicated() external {
    (address[] memory removingOperators, address[] memory removingGovernors, uint96[] memory removingWeights, , , ) = _generateRemovingOperators(2);

    removingOperators[1] = removingOperators[0];
    removingGovernors[1] = removingGovernors[0];
    removingWeights[1] = removingWeights[0];

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(AddressArrayUtils.ErrDuplicated.selector, IBridgeManager.removeBridgeOperators.selector));
    _bridgeManager.removeBridgeOperators(removingOperators);
  }

  function test_RemoveOperators_TwoAddress_ThatValid() external {
    uint TO_REMOVE_NUM = 2;

    (
      address[] memory removingOperators,
      address[] memory removingGovernors,
      uint96[] memory removingWeights,
      address[] memory remainingOperators,
      address[] memory remainingGovernors,
      uint96[] memory remainingWeights
    ) = _generateRemovingOperators(TO_REMOVE_NUM);

    bool[] memory removeds = _bridgeManager.removeBridgeOperators(removingOperators);
    bool[] memory expectedRemoved = new bool[](TO_REMOVE_NUM);
    expectedRemoved[0] = true;
    expectedRemoved[1] = true;
    assertEq(removeds, expectedRemoved);

    address[] memory zeroAddressArrays = new address[](TO_REMOVE_NUM);
    zeroAddressArrays[0] = address(0);
    zeroAddressArrays[1] = address(0);

    assertEq(_bridgeManager.totalBridgeOperator(), _bridgeOperators.length - TO_REMOVE_NUM, "wrong total bridge operator");
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight - (LibArrayUtils.sum(removingWeights)), "wrong total total weight");

    for (uint i; i < TO_REMOVE_NUM; i++) {
      vm.expectRevert(abi.encodeWithSelector(IBridgeManager.ErrGovernorNotFound.selector, removingGovernors[i]));
      _bridgeManager.getOperatorOf(removingGovernors[i]);

      vm.expectRevert(abi.encodeWithSelector(IBridgeManager.ErrOperatorNotFound.selector, removingOperators[i]));
      _bridgeManager.getGovernorOf(removingOperators[i]);
    }

    // Compare after and before state
    (address[] memory afterBridgeOperators, address[] memory afterGovernors, uint96[] memory afterVoteWeights) = _getBridgeMembersByGovernors(
      remainingGovernors
    );

    _assertBridgeMembers({
      comparingOperators: afterBridgeOperators,
      comparingGovernors: afterGovernors,
      comparingWeights: afterVoteWeights,
      expectingOperators: remainingOperators,
      expectingGovernors: remainingGovernors,
      expectingWeights: remainingWeights
    });
  }
}
