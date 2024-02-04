// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { GatewayV3 } from "@ronin/contracts/extensions/GatewayV3.sol";
import "../BaseIntegration.t.sol";

contract EmergencyAction_PauseEnforcer_Test is BaseIntegration_Test {
  error ErrTargetIsNotOnPaused();

  function setUp() public virtual override {
    super.setUp();
  }

  // Emergency pause & emergency unpause > Should be able to emergency pause
  function test_EmergencyPause_RoninGatewayV3() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerPause();

    assertEq(_roninPauseEnforcer.emergency(), true);
    assertEq(_roninGatewayV3.paused(), true);
  }

  // Emergency pause & emergency unpause > Should the gateway cannot interacted when on pause
  function test_RevertWhen_InteractWithGateway_AfterPause() public {
    test_EmergencyPause_RoninGatewayV3();
    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: Token.Owner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert("Pausable: paused");

    _roninGatewayV3.depositFor(receipt);
  }

  // Emergency pause & emergency unpause > Should not be able to emergency pause for a second time
  function test_RevertWhen_PauseAgain() public {
    test_EmergencyPause_RoninGatewayV3();

    vm.expectRevert(ErrTargetIsNotOnPaused.selector);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerPause();
  }

  // Emergency pause & emergency unpause > Should be able to emergency unpause
  function test_EmergencyUnpause_RoninGatewayV3() public {
    test_EmergencyPause_RoninGatewayV3();

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerUnpause();

    assertEq(_roninPauseEnforcer.emergency(), false);
    assertEq(_roninGatewayV3.paused(), false);
  }

  // Emergency pause & emergency unpause > Should the gateway can be interacted after unpause
  function test_InteractWithGateway_AfterUnpause() public {
    test_EmergencyUnpause_RoninGatewayV3();
    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: Token.Owner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    uint256 numOperatorsForVoteExecuted =
      _param.roninBridgeManager.bridgeOperators.length * _param.roninBridgeManager.num / _param.roninBridgeManager.denom;
    for (uint256 i; i < numOperatorsForVoteExecuted; i++) {
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.depositFor(receipt);
    }
  }
}
