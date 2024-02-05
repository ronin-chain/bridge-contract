// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BaseIntegration.t.sol";

contract AccessControl_PauseEnforcer_Test is BaseIntegration_Test {
  function setUp() public virtual override {
    super.setUp();
  }

  // Access control > Should admin of pause enforcer can be change
  function test_changeAdmin_OfPauseEnforcer() public {
    address newEnforcerAdmin = makeAddr("new-enforcer-admin");

    vm.prank(_param.roninPauseEnforcer.admin);
    _roninPauseEnforcer.grantRole(0x0, newEnforcerAdmin);

    assertEq(_roninPauseEnforcer.hasRole(0x0, newEnforcerAdmin), true);
  }

  // Access control > Should previous admin of pause enforcer can be revoked
  function test_renounceAdminRole_PreviousAdmin() public {
    test_changeAdmin_OfPauseEnforcer();

    assertEq(_roninPauseEnforcer.hasRole(0x0, _param.roninPauseEnforcer.admin), true);

    vm.prank(_param.roninPauseEnforcer.admin);
    _roninPauseEnforcer.renounceRole(0x0, _param.roninPauseEnforcer.admin);

    assertEq(_roninPauseEnforcer.hasRole(0x0, _param.roninPauseEnforcer.admin), false);
  }
}
