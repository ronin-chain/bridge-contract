// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer as LibTransfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";

import "../BaseIntegration.t.sol";

interface IERC721 {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
}

interface IERC20 {
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract RequestDepositFor_MainchainGatewayV3_Test is BaseIntegration_Test {
  event DepositRequested(bytes32 receiptHash, LibTransfer.Receipt receipt);

  using LibTransfer for LibTransfer.Request;
  using LibTransfer for LibTransfer.Receipt;

  LibTransfer.Request _depositRequest;

  address _sender;
  uint256 _quantity;

  function setUp() public virtual override {
    super.setUp();

    _sender = makeAddr("sender");
    _quantity = 10;

    _depositRequest.recipientAddr = makeAddr("recipient");
    _depositRequest.tokenAddr = address(0);
    _depositRequest.info.erc = Token.Standard.ERC20;
    _depositRequest.info.id = 0;
    _depositRequest.info.quantity = _quantity;

    vm.deal(_sender, 10 ether);
  }

  // test deposit > should be able to deposit eth
  function test_depositNative() public {
    _depositRequest.tokenAddr = address(0);

    LibTransfer.Request memory cachedRequest = _depositRequest;
    cachedRequest.tokenAddr = address(_mainchainWeth);

    vm.expectEmit(address(_mainchainGatewayV3));
    LibTransfer.Receipt memory receipt = cachedRequest.into_deposit_receipt(
      _sender, _mainchainGatewayV3.depositCount(), address(_roninWeth), block.chainid
    );
    emit DepositRequested(receipt.hash(), receipt);

    vm.prank(_sender);
    _mainchainGatewayV3.requestDepositFor{ value: _quantity }(_depositRequest);

    assertEq(address(_mainchainGatewayV3).balance, _quantity);
    assertEq(_mainchainGatewayV3.depositCount(), 1);
  }

  // test deposit > should be able to deposit ERC20
  function test_depositERC20() public {
    _mainchainAxs.mint(_sender, _quantity);
    vm.prank(_sender);
    _mainchainAxs.approve(address(_mainchainGatewayV3), _quantity);

    _depositRequest.tokenAddr = address(_mainchainAxs);

    vm.expectEmit(address(_mainchainGatewayV3));
    LibTransfer.Receipt memory receipt = _depositRequest.into_deposit_receipt(
      _sender, _mainchainGatewayV3.depositCount(), address(_roninAxs), block.chainid
    );
    emit DepositRequested(receipt.hash(), receipt);

    vm.prank(_sender);
    _mainchainGatewayV3.requestDepositFor(_depositRequest);

    assertEq(_mainchainAxs.balanceOf(address(_mainchainGatewayV3)), _quantity);
    assertEq(_mainchainGatewayV3.depositCount(), 1);
  }

  // test deposit > should be able to deposit weth and gateway receive eth
  function test_depositERC721() public {
    uint256 tokenId = 22;
    _mainchainMockERC721.mint(_sender, tokenId);
    vm.prank(_sender);
    _mainchainMockERC721.approve(address(_mainchainGatewayV3), tokenId);

    _depositRequest.tokenAddr = address(_mainchainMockERC721);
    _depositRequest.info.erc = Token.Standard.ERC721;
    _depositRequest.info.id = tokenId;
    _depositRequest.info.quantity = 0;

    LibTransfer.Receipt memory receipt = _depositRequest.into_deposit_receipt(
      _sender, _mainchainGatewayV3.depositCount(), address(_roninMockERC721), block.chainid
    );
    vm.expectEmit(address(_mainchainGatewayV3));
    emit DepositRequested(receipt.hash(), receipt);

    assertEq(_mainchainMockERC721.ownerOf(tokenId), _sender);

    vm.prank(_sender);
    _mainchainGatewayV3.requestDepositFor(_depositRequest);

    assertEq(_mainchainMockERC721.ownerOf(tokenId), address(_mainchainGatewayV3));
    assertEq(_mainchainGatewayV3.depositCount(), 1);
  }

  // test deposit > should be able to unwrap and deposit native.
  function test_unwrapAndDepositNative() public {
    vm.startPrank(_sender);
    _mainchainWeth.deposit{ value: _quantity }();
    _mainchainWeth.approve(address(_mainchainGatewayV3), _quantity);
    vm.stopPrank();

    _depositRequest.tokenAddr = address(_mainchainWeth);

    LibTransfer.Receipt memory receipt = _depositRequest.into_deposit_receipt(
      _sender, _mainchainGatewayV3.depositCount(), address(_roninWeth), block.chainid
    );
    vm.expectEmit(address(_mainchainGatewayV3));
    emit DepositRequested(receipt.hash(), receipt);

    assertEq(address(_mainchainWeth).balance, _quantity);

    vm.prank(_sender);
    _mainchainGatewayV3.requestDepositFor(_depositRequest);

    assertEq(address(_mainchainGatewayV3).balance, _quantity);
    assertEq(_mainchainGatewayV3.depositCount(), 1);
  }
}
