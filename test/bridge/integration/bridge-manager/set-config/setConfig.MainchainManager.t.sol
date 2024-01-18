// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import "../../BaseIntegration.t.sol";

contract SetConfig_MainchainManager_Test is BaseIntegration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  function test_configBridgeContractCorrectly() external {
    address bridgeContract = _mainchainBridgeManager.getContract(ContractType.BRIDGE);
    assertEq(bridgeContract, address(_mainchainGatewayV3));
  }

  function test_configBridgeOperatorsCorrectly() external {
    address[] memory bridgeOperators = _mainchainBridgeManager.getBridgeOperators();

    assertEq(bridgeOperators, _param.mainchainBridgeManager.bridgeOperators);
  }

  function test_configTargetsCorrectly() external {
    GlobalProposal.TargetOption[] memory targets = new GlobalProposal.TargetOption[](5);
    targets[0] = GlobalProposal.TargetOption.BridgeManager;
    targets[1] = GlobalProposal.TargetOption.GatewayContract;
    targets[2] = GlobalProposal.TargetOption.BridgeSlash;
    targets[3] = GlobalProposal.TargetOption.BridgeReward;
    targets[4] = GlobalProposal.TargetOption.BridgeTracking;

    address[] memory results = _mainchainBridgeManager.resolveTargets(targets);

    assertEq(results[0], address(_mainchainBridgeManager));
    assertEq(results[1], address(_mainchainGatewayV3));
    assertEq(results[2], address(address(0)));
    assertEq(results[3], address(address(0)));
    assertEq(results[4], address(address(0)));
  }
}
