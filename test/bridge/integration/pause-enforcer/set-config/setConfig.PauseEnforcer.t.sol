// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import "../../BaseIntegration.t.sol";

contract SetConfig_PauseEnforcer_Test is BaseIntegration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  function test_configPauseEnforcerContract() public {
    (, bytes memory ret) = address(_roninGatewayV3).staticcall(abi.encodeWithSignature("emergencyPauser()"));
    assertEq(abi.decode(ret, (address)), address(_roninPauseEnforcer));
  }

  function test_configBridgeContract() public {
    address bridgeContract = address(_roninPauseEnforcer.target());

    assertEq(bridgeContract, address(_roninGatewayV3));
  }

  function test_sentryEnforcerRole() public {
    bool isSentryRole = _roninPauseEnforcer.hasRole(_roninPauseEnforcer.SENTRY_ROLE(), _param.roninPauseEnforcer.sentries[0]);

    assertEq(isSentryRole, true);
  }
}
