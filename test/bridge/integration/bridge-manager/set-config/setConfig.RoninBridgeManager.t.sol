// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BridgeManager_IntergrationTest.t.sol";

contract SetConfig_RoninBridgeManager_Test is Bridge_Integration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  function test_setBridgeContract() external {
    address bridgeContract = _roninBridgeManager.getContract(ContractType.BRIDGE);
    assertEq(bridgeContract, address(_bridgeContract));
  }

  function test_setBridgeOperatorsContract() external {
    address[] memory bridgeOperators = _roninBridgeManager.getBridgeOperators();
    for (uint256 i; i < bridgeOperators.length; i++) {
      assertEq(bridgeOperators[i], _operators[i].addr);
    }
  }
}
