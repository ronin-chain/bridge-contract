// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer as LibTransfer } from "@ronin/contracts/libraries/Transfer.sol";
import "@ronin/contracts/libraries/LibTokenInfoBatch.sol";

import "../BaseIntegration.t.sol";

contract RequestDepositFor_Batch_MainchainGatewayV3_Test is BaseIntegration_Test {
  event DepositRequested(bytes32 receiptHash, LibTransfer.Receipt receipt);

  using LibTransfer for LibTransfer.Request;
  using LibTransfer for LibTransfer.Receipt;

  // LibTransfer.Request _depositRequest;

  address _sender;
  uint256 _quantity;

  function setUp() public virtual override {
    super.setUp();

    _sender = makeAddr("sender");
    _quantity = 10;

    // _depositRequest.recipientAddr = makeAddr("recipient");
    // _depositRequest.tokenAddr = address(0);
    // _depositRequest.info.erc = TokenStandard.ERC20;
    // _depositRequest.info.id = 0;
    // _depositRequest.info.quantity = _quantity;

    vm.deal(_sender, 10 ether);
  }

  // deposit erc721 in batch (2 ids), both success
  // function test_depositERC721Batch_Success() public {
  //   uint256 tokenId1 = 22;
  //   uint256 tokenId2 = 23;
  //   _mainchainMockERC721.mint(_sender, tokenId1);
  //   _mainchainMockERC721.mint(_sender, tokenId2);
  //   vm.startPrank(_sender);
  //   _mainchainMockERC721.approve(address(_mainchainGatewayV3), tokenId1);
  //   _mainchainMockERC721.approve(address(_mainchainGatewayV3), tokenId2);
  //   vm.stopPrank();

  //   _depositRequest.tokenAddr = address(_mainchainMockERC721);
  //   _depositRequest.info.erc = TokenStandard.ERC721;
  //   _depositRequest.info.id = 0;
  //   _depositRequest.info.quantity = 0;
  //   _depositRequest.info.ids = new uint256[](2);
  //   _depositRequest.info.ids[0] = tokenId1;
  //   _depositRequest.info.ids[1] = tokenId2;
  //   _depositRequest.info.quantities = new uint256[](2);

  //   LibTransfer.Receipt memory receipt = _depositRequest.into_deposit_receipt(
  //     _sender, _mainchainGatewayV3.depositCount(), address(_roninMockERC721), block.chainid
  //   );
  //   vm.expectEmit(address(_mainchainGatewayV3));
  //   emit DepositRequested(receipt.hash(), receipt);

  //   assertEq(_mainchainMockERC721.ownerOf(tokenId1), _sender);
  //   assertEq(_mainchainMockERC721.ownerOf(tokenId2), _sender);

  //   vm.prank(_sender);
  //   _mainchainGatewayV3.requestDepositFor(_depositRequest);

  //   assertEq(_mainchainMockERC721.ownerOf(tokenId1), address(_mainchainGatewayV3));
  //   assertEq(_mainchainMockERC721.ownerOf(tokenId2), address(_mainchainGatewayV3));
  //   assertEq(_mainchainGatewayV3.depositCount(), 1);
  // }

  function test_depositERC721Batch_Success() public {
    uint256 tokenId1 = 22;
    uint256 tokenId2 = 23;
    _mainchainMockERC721.mint(_sender, tokenId1);
    _mainchainMockERC721.mint(_sender, tokenId2);

    vm.startPrank(_sender);
    _mainchainMockERC721.approve(address(_mainchainGatewayBatcher), tokenId1);
    _mainchainMockERC721.approve(address(_mainchainGatewayBatcher), tokenId2);

    MainchainGatewayBatcher.RequestBatch memory req;
    req.recipient = makeAddr("recipient");
    req.tokenAddr = address(_mainchainMockERC721);
    req.info.erc = TokenStandard.ERC721;
    req.info.ids = new uint256[](2);
    req.info.ids[0] = tokenId1;
    req.info.ids[1] = tokenId2;

    assertEq(_mainchainMockERC721.ownerOf(tokenId1), _sender);
    assertEq(_mainchainMockERC721.ownerOf(tokenId2), _sender);

    _mainchainGatewayBatcher.requestDepositForBatch(req);

    // LibTransfer.Receipt memory receipt = _depositRequest.into_deposit_receipt(
    //   _sender, _mainchainGatewayV3.depositCount(), address(_roninMockERC721), block.chainid
    // );
    // vm.expectEmit(address(_mainchainGatewayV3));
    // emit DepositRequested(receipt.hash(), receipt);

    assertEq(_mainchainMockERC721.ownerOf(tokenId1), address(_mainchainGatewayV3));
    assertEq(_mainchainMockERC721.ownerOf(tokenId2), address(_mainchainGatewayV3));
    assertEq(_mainchainGatewayV3.depositCount(), 2);
  }
}
