// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BridgeManager_IntegrationTest.t.sol";

contract SetConfig_RoninBridgeManager_Test is Bridge_Integration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  function test_configBridgeContractCorrectly() external {
    address bridgeContract = _roninBridgeManager.getContract(ContractType.BRIDGE);
    assertEq(bridgeContract, address(_roninGatewayV3Contract));
  }

  function test_configBridgeOperatorsCorrectly() external {
    address[] memory bridgeOperators = _roninBridgeManager.getBridgeOperators();

    for (uint256 i; i < bridgeOperators.length; i++) {
      assertEq(bridgeOperators[i], _operators[i].addr);
    }
  }

  function test_configTargetsCorrectly() external {
    GlobalProposal.TargetOption[] memory targets = new GlobalProposal.TargetOption[](5);
    targets[0] = GlobalProposal.TargetOption.BridgeManager;
    targets[1] = GlobalProposal.TargetOption.GatewayContract;
    targets[2] = GlobalProposal.TargetOption.BridgeSlash;
    targets[3] = GlobalProposal.TargetOption.BridgeReward;
    targets[4] = GlobalProposal.TargetOption.BridgeTracking;

    address[] memory results = _roninBridgeManager.resolveTargets(targets);

    assertEq(results[0], address(_roninBridgeManager));
    assertEq(results[1], address(_roninGatewayV3Contract));
    assertEq(results[2], address(_bridgeSlash));
    assertEq(results[3], address(_bridgeReward));
    assertEq(results[4], address(_bridgeTracking));
  }
}
