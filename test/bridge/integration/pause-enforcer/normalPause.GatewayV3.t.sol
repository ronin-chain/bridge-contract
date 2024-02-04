// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { GatewayV3 } from "@ronin/contracts/extensions/GatewayV3.sol";
import "../BaseIntegration.t.sol";

contract NormalPause_GatewayV3_Test is BaseIntegration_Test {
  error ErrNotOnEmergencyPause();
  error ErrTargetIsNotOnPaused();

  function setUp() public virtual override {
    super.setUp();
  }

  // Normal pause & emergency unpause > Should gateway admin can pause the gateway through voting
  function test_GovernanceAdmin_PauseGateway_ThroughoutVoting() public {
    bytes memory calldata_ = abi.encodeCall(GatewayV3.pause, ());
    _roninProposalUtils.functionDelegateCall(address(_roninGatewayV3), calldata_);

    assertEq(_roninPauseEnforcer.emergency(), false);
    assertEq(_roninGatewayV3.paused(), true);
  }

  // Normal pause & emergency unpause > Should not be able to emergency unpause
  function test_RevertWhen_EmergencyUnpause() public {
    test_GovernanceAdmin_PauseGateway_ThroughoutVoting();

    vm.expectRevert(ErrNotOnEmergencyPause.selector);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerUnpause();
  }

  // Normal pause & emergency unpause > Should not be able to override by emergency pause and emergency unpause
  function test_RevertWhen_OverrideByEmergencyPauseOrUnPause() public {
    test_GovernanceAdmin_PauseGateway_ThroughoutVoting();

    vm.expectRevert(ErrTargetIsNotOnPaused.selector);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerPause();

    vm.expectRevert(ErrNotOnEmergencyPause.selector);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerUnpause();
  }

  // Normal pause & emergency unpause > Should gateway admin can unpause the gateway through voting
  function test_GovernanceAdmin_UnPauseGateway_ThroughoutVoting() public {
    test_GovernanceAdmin_PauseGateway_ThroughoutVoting();

    bytes memory calldata_ = abi.encodeCall(GatewayV3.unpause, ());
    _roninProposalUtils.functionDelegateCall(address(_roninGatewayV3), calldata_);

    assertEq(_roninPauseEnforcer.emergency(), false);
    assertEq(_roninGatewayV3.paused(), false);
  }
}
