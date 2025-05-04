// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { GatewayV3 } from "@ronin/contracts/extensions/GatewayV3.sol";
import { LibTokenOwner, TokenOwner } from "@ronin/contracts/libraries/LibTokenOwner.sol";
import { FunctionRestrictable } from "@ronin/contracts/extensions/FunctionRestrictable.sol";
import "../BaseIntegration.t.sol";

contract EmergencyAction_PauseEnforcer_Test is BaseIntegration_Test {
  error ErrTargetIsNotOnPaused();

  // Emergency pause & emergency unpause > Should be able to emergency pause
  function test_EmergencyPause_RoninGatewayV3() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerPause();

    assertEq(_roninPauseEnforcer.emergency(), true, "emergency");
    assertEq(IPauseTarget(address(_roninGatewayV3)).paused(), true, "paused");
  }

  // Emergency pause & emergency unpause > Should the gateway cannot interacted when on pause
  function test_RevertWhen_InteractWithGateway_AfterPause() public {
    test_EmergencyPause_RoninGatewayV3();
    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: TokenOwner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: TokenOwner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });
    // ids: new uint256[](0),
    // quantities: new uint256[](0)

    vm.expectRevert("Pausable: paused");

    _roninGatewayV3.depositFor(receipt);
  }

  // Emergency pause & emergency unpause > Should not be able to emergency pause for a second time
  function test_RevertWhen_PauseAgain() public {
    test_EmergencyPause_RoninGatewayV3();

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    vm.expectRevert(ErrTargetIsNotOnPaused.selector);
    _roninPauseEnforcer.triggerPause();
  }

  // Emergency pause & emergency unpause > Should be able to emergency unpause
  function test_EmergencyUnpause_RoninGatewayV3() public {
    test_EmergencyPause_RoninGatewayV3();

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerUnpause();

    assertEq(_roninPauseEnforcer.emergency(), false);
    assertEq(IPauseTarget(address(_roninGatewayV3)).paused(), false);
  }

  function test_RevertWhen_Restrict_ERC20() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    uint8 enumBitmap = uint8(1 << uint8(TokenStandard.ERC20));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    Transfer.Request memory request = Transfer.Request({
      recipientAddr: makeAddr("recipient"),
      tokenAddr: address(_roninWeth),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);
  }

  function test_RevertWhen_Restrict_MultipleStandard() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    uint8 enumBitmap = uint8(1 << uint8(TokenStandard.ERC20)) | uint8(1 << uint8(TokenStandard.ERC721));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    Transfer.Request memory request = Transfer.Request({
      recipientAddr: makeAddr("recipient"),
      tokenAddr: address(_roninWeth),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC721;
    request.info.quantity = 0;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC721));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);
  }

  function test_SuccessWhen_Restrict_MultipleStandards_Then_Unrestrict_SomeStandards() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    uint8 enumBitmap = uint8(1 << uint8(TokenStandard.ERC20)) | uint8(1 << uint8(TokenStandard.ERC721));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    Transfer.Request memory request = Transfer.Request({
      recipientAddr: makeAddr("recipient"),
      tokenAddr: address(_roninWeth),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC721;
    request.info.quantity = 0;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC721));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    enumBitmap = uint8(1 << uint8(TokenStandard.ERC721));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC721));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC20;
    request.info.quantity = 100;

    deal(address(_roninWeth), address(this), 100);
    _roninWeth.approve(address(_roninGatewayV3), 100);

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);
  }

  function test_SuccessWhen_Restrict_Then_Unrestrict() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    uint8 enumBitmap = uint8(1 << uint8(TokenStandard.ERC20));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    Transfer.Request memory request = Transfer.Request({
      recipientAddr: makeAddr("recipient"),
      tokenAddr: address(_roninWeth),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    deal(address(_roninWeth), address(this), 100);
    _roninWeth.approve(address(_roninGatewayV3), 100);

    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, 0);

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);
  }

  function test_RevertWhen_Restrict_AllStandard() public {
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    uint8 enumBitmap = uint8(1 << uint8(TokenStandard.ERC20)) | uint8(1 << uint8(TokenStandard.ERC721)) | uint8(1 << uint8(TokenStandard.ERC1155));
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    Transfer.Request memory request = Transfer.Request({
      recipientAddr: makeAddr("recipient"),
      tokenAddr: address(_roninWeth),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC721;
    request.info.quantity = 0;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC721));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC1155;
    request.info.quantity = 100;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC1155));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    enumBitmap = type(uint8).max;
    vm.prank(_param.roninPauseEnforcer.sentries[0]);
    _roninPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, enumBitmap);

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));

    request.info.erc = TokenStandard.ERC20;
    request.info.quantity = 100;

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC721;
    request.info.quantity = 0;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC721));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);

    request.info.erc = TokenStandard.ERC1155;
    request.info.quantity = 100;

    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC1155));

    _roninGatewayV3.requestWithdrawalFor(request, block.chainid);
  }

  // Emergency pause & emergency unpause > Should the gateway can be interacted after unpause
  function test_InteractWithGateway_AfterUnpause() public {
    test_EmergencyUnpause_RoninGatewayV3();
    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: TokenOwner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: TokenOwner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });
    // ids: new uint256[](0),
    // quantities: new uint256[](0)

    uint256 numOperatorsForVoteExecuted = _param.roninBridgeManager.bridgeOperators.length * _param.roninBridgeManager.num / _param.roninBridgeManager.denom;
    for (uint256 i; i < numOperatorsForVoteExecuted; i++) {
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.depositFor(receipt);
    }
  }
}
