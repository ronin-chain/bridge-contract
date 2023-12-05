// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/console2.sol";
import {StdStyle} from "forge-std/StdStyle.sol";

import {IBridgeManager} from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import {MockBridgeManager} from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import {RoninBridgeManager} from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import {MockBridge} from "@ronin/contracts/mocks/MockBridge.sol";

import {Base_Test} from "@ronin/test/Base.t.sol";
import {SignerUtils} from "@ronin/test/utils/Signers.sol";
import {InitTestOutput} from "@ronin/test/init-test/Structs.sol";
import {InitTest} from "@ronin/test/init-test/InitTest.sol";
import "./BridgeManagerInterface.sol";

contract Bridge_Integration_Test is Base_Test, InitTest, SignerUtils {
  uint256 internal _operatorNum;
  uint256 internal _bridgeAdminNumerator;
  uint256 internal _bridgeAdminDenominator;

  MockBridge internal _bridgeContract;
  RoninBridgeManager internal _bridgeManagerContract;
  Account[] internal _operators;
  BridgeManagerInterface _bridgeManagerInterface;

  function setUp() public virtual {
    _setOperators(_getSigners(_operatorNum));
    _prepareDeploymentArgs();

    InitTestOutput memory output = init();

    _bridgeContract = MockBridge(output.bridgeContractAddress);
    _bridgeManagerContract = RoninBridgeManager(output.roninBridgeManagerAddress);
  }

  function _prepareDeploymentArgs() internal {
    _operatorNum = 6;
    _bridgeAdminNumerator = 2;
    _bridgeAdminDenominator = 4;
  }

  function _setOperators(Account[] memory operators) internal {
    delete _operators;
    for (uint256 i; i < operators.length; i++) {
      _operators.push(operators[i]);
    }
  }

  function test_abc() external {}
}
