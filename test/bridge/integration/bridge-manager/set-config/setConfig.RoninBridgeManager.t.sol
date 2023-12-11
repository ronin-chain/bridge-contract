// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BridgeManager_IntergrationTest.t.sol";

contract SetConfig_RoninBridgeManager_Test is Bridge_Integration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  function test_setConfigCorrect() external {
    address bridgeContract = _roninBridgeManager.getContract(ContractType.BRIDGE);
    address[] memory bridgeOperators = _roninBridgeManager.getBridgeOperators();
  }
}
