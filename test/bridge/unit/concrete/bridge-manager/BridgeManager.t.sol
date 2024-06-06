// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract BridgeManager_Unit_Concrete_Test is Base_Test {
  IBridgeManager internal _bridgeManager;
  address[] internal _bridgeOperators;
  address[] internal _governors;
  uint96[] internal _voteWeights;
  uint256 internal _totalWeight;
  uint256 internal _totalOperator;
  address internal _admin;

  modifier assertStateNotChange() {
    // Get before test state
    (address[] memory beforeBridgeOperators, address[] memory beforeGovernors, uint96[] memory beforeVoteWeights) = _getBridgeMembers();

    _;

    // Compare after and before state
    (address[] memory afterBridgeOperators, address[] memory afterGovernors, uint96[] memory afterVoteWeights) = _getBridgeMembers();

    _assertBridgeMembers({
      comparingOperators: beforeBridgeOperators,
      expectingOperators: afterBridgeOperators,
      comparingGovernors: beforeGovernors,
      expectingGovernors: afterGovernors,
      comparingWeights: beforeVoteWeights,
      expectingWeights: afterVoteWeights
    });
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight);
  }

  function setUp() public virtual {
    address[] memory bridgeOperators = new address[](5);
    bridgeOperators[0] = address(0x10000);
    bridgeOperators[1] = address(0x10001);
    bridgeOperators[2] = address(0x10002);
    bridgeOperators[3] = address(0x10003);
    bridgeOperators[4] = address(0x10004);

    address[] memory governors = new address[](5);
    governors[0] = address(0x20000);
    governors[1] = address(0x20001);
    governors[2] = address(0x20002);
    governors[3] = address(0x20003);
    governors[4] = address(0x20004);

    uint96[] memory voteWeights = new uint96[](5);
    voteWeights[0] = 100;
    voteWeights[1] = 100;
    voteWeights[2] = 100;
    voteWeights[3] = 100;
    voteWeights[4] = 100;

    for (uint i; i < bridgeOperators.length; i++) {
      _bridgeOperators.push(bridgeOperators[i]);
      _governors.push(governors[i]);
      _voteWeights.push(voteWeights[i]);
    }

    _totalWeight = 500;
    _totalOperator = 5;

    _admin = makeAddr("bridgeManagerAdmin");
    address bridgeManagerLogic = address(new MockBridgeManager());
    _bridgeManager = MockBridgeManager(
      address(
        new TransparentUpgradeableProxyV2(bridgeManagerLogic, _admin, abi.encodeCall(MockBridgeManager.initialize, (bridgeOperators, governors, voteWeights)))
      )
    );
  }

  function _generateNewOperators() internal pure returns (address[] memory operators, address[] memory governors, uint96[] memory weights) {
    operators = new address[](1);
    operators[0] = address(0x10099);

    governors = new address[](1);
    governors[0] = address(0x20099);

    weights = new uint96[](1);
    weights[0] = 100;
  }

  function _generateRemovingOperators(uint removingNumber)
    internal
    view
    returns (
      address[] memory removingOperators,
      address[] memory removingGovernors,
      uint96[] memory removingWeights,
      address[] memory remainingOperators,
      address[] memory remainingGovernors,
      uint96[] memory remainingWeights
    )
  {
    if (removingNumber > _totalOperator) {
      revert("_generateRemovingOperators: exceed number to remove");
    }

    uint remainingNumber = _totalOperator - removingNumber;

    removingOperators = new address[](removingNumber);
    removingGovernors = new address[](removingNumber);
    removingWeights = new uint96[](removingNumber);
    remainingOperators = new address[](remainingNumber);
    remainingGovernors = new address[](remainingNumber);
    remainingWeights = new uint96[](remainingNumber);

    for (uint i; i < removingNumber; i++) {
      removingOperators[i] = _bridgeOperators[i];
      removingGovernors[i] = _governors[i];
      removingWeights[i] = _voteWeights[i];
    }

    for (uint i = removingNumber; i < _totalOperator; i++) {
      remainingOperators[i - removingNumber] = _bridgeOperators[i];
      remainingGovernors[i - removingNumber] = _governors[i];
      remainingWeights[i - removingNumber] = _voteWeights[i];
    }
  }

  function _generateBridgeOperatorAddressToUpdate() internal pure returns (address) {
    return address(0x10010);
  }

  function _getBridgeMembers() internal view returns (address[] memory operators, address[] memory governors, uint96[] memory weights) {
    // (governors, operators, weights) = _bridgeManager.getFullBridgeOperatorInfos();
    address[] memory governors_ = _bridgeManager.getGovernors();
    return _getBridgeMembersByGovernors(governors_);
  }

  function _getBridgeMembersByGovernors(address[] memory queryingGovernors)
    internal
    view
    returns (address[] memory operators, address[] memory governors, uint96[] memory weights)
  {
    governors = queryingGovernors;

    operators = new address[](queryingGovernors.length);
    for (uint i; i < queryingGovernors.length; i++) {
      operators[i] = _bridgeManager.getOperatorOf(queryingGovernors[i]);
    }

    weights = _bridgeManager.getGovernorWeights(queryingGovernors);
  }

  function _assertBridgeMembers(
    address[] memory comparingOperators,
    address[] memory expectingOperators,
    address[] memory comparingGovernors,
    address[] memory expectingGovernors,
    uint96[] memory comparingWeights,
    uint96[] memory expectingWeights
  ) internal {
    assertEq(comparingOperators.length, expectingOperators.length, "wrong bridge operators length");
    assertEq(comparingGovernors.length, expectingGovernors.length, "wrong governors length");
    assertEq(comparingWeights.length, expectingWeights.length, "wrong weights length");

    assertEq(comparingOperators, expectingOperators, "wrong bridge operators");
    assertEq(comparingGovernors, expectingGovernors, "wrong governors");
    assertEq(comparingWeights, expectingWeights, "wrong weights");
  }
}
