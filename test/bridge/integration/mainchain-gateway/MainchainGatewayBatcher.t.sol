// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration_Test, MockERC721, MockERC1155 } from "../BaseIntegration.t.sol";
import { TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { RequestBatch } from "@ronin/contracts/libraries/LibRequestBatch.sol";

contract MainchainGatewayBatcherTest is BaseIntegration_Test {
  function testConcrete_RevertIf_WrongTokenStandardERC1155_requestDepositForBatch_ERC721() external {
    _mainchainMockERC721.mint(sender, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC721);
    req.info.erc = TokenStandard.ERC1155; // ERC1155 instead of ERC721
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;
    req.info.quantities = new uint256[](1);
    req.info.quantities[0] = 1;

    vm.startPrank(sender);
    _mainchainMockERC721.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_WrongTokenStandardERC721_requestDepositForBatch_ERC1155() external {
    _mainchainMockERC1155.mint(sender, 1, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC1155);
    req.info.erc = TokenStandard.ERC721; // ERC721 instead of ERC1155
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;

    vm.startPrank(sender);
    _mainchainMockERC1155.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_WrongTokenStandardERC20_requestDepositForBatch_ERC721() external {
    _mainchainMockERC721.mint(sender, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC721);
    req.info.erc = TokenStandard.ERC20; // ERC20 instead of ERC721
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;

    vm.startPrank(sender);
    _mainchainMockERC721.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_WrongTokenStandardERC721_requestDepositForBatch_ERC20() external {
    deal(address(_mainchainMockERC20), sender, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC20);
    req.info.erc = TokenStandard.ERC721; // ERC721 instead of ERC20
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;

    vm.startPrank(sender);
    _mainchainMockERC20.approve(address(_mainchainGatewayBatcher), 1);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_WrongTokenStandardERC721_requestDepositForBatch_PoisonERC20() external {
    deal(address(_mainchainMockPoisonERC20), sender, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockPoisonERC20);
    req.info.erc = TokenStandard.ERC721; // ERC721 instead of ERC20
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;

    vm.startPrank(sender);
    _mainchainMockPoisonERC20.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_WrongTokenStandardERC20_requestDepositForBatch_ERC1155() external {
    _mainchainMockERC1155.mint(sender, 1, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC1155);
    req.info.erc = TokenStandard.ERC20; // ERC20 instead of ERC1155
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;

    vm.startPrank(sender);
    _mainchainMockERC1155.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testConcrete_RevertIf_LengthMismatch_requestDepositForBatch_ERC1155() external {
    _mainchainMockERC1155.mint(sender, 1, 1);

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC1155);
    req.info.erc = TokenStandard.ERC1155;
    req.info.ids = new uint256[](1);
    req.info.ids[0] = 1;
    req.info.quantities = new uint256[](2); // Length mismatch

    vm.startPrank(sender);
    _mainchainMockERC1155.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    vm.expectRevert();
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();
  }

  function testFuzz_requestDepositBatch_ERC1155(uint256[] calldata ids) external {
    uint256[] memory amounts = new uint256[](ids.length);

    vm.assume(ids.length != 0);
    vm.assume(!hasDuplicate(ids));
    vm.assume(ids.length == amounts.length);

    for (uint256 i; i < ids.length; i++) {
      amounts[i] = 1;
    }
    for (uint256 i; i < ids.length; i++) {
      _mainchainMockERC1155.mint(sender, ids[i], amounts[i]);
    }

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC1155);
    req.info.erc = TokenStandard.ERC1155;
    req.info.ids = ids;
    req.info.quantities = new uint256[](ids.length);
    for (uint256 i; i < ids.length; i++) {
      req.info.quantities[i] = 1;
    }

    vm.startPrank(sender);
    _mainchainMockERC1155.setApprovalForAll(address(_mainchainGatewayBatcher), true);
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();

    for (uint256 i; i < ids.length; i++) {
      assertEq(_mainchainMockERC1155.balanceOf(sender, ids[i]), 0);
      assertEq(_mainchainMockERC1155.balanceOf(address(_mainchainGatewayV3), ids[i]), 1);
    }
  }

  function testFuzz_requestDepositBatch_ERC721(uint256[] calldata ids) external {
    vm.assume(ids.length != 0);
    vm.assume(!hasDuplicate(ids));

    for (uint256 i; i < ids.length; i++) {
      _mainchainMockERC721.mint(sender, ids[i]);
    }

    RequestBatch memory req;
    req.recipient = sender;
    req.tokenAddr = address(_mainchainMockERC721);
    req.info.erc = TokenStandard.ERC721;
    req.info.ids = ids;

    vm.startPrank(sender);
    for (uint256 i; i < ids.length; i++) {
      _mainchainMockERC721.approve(address(_mainchainGatewayBatcher), ids[i]);
    }
    _mainchainGatewayBatcher.requestDepositForBatch(req);
    vm.stopPrank();

    for (uint256 i; i < ids.length; i++) {
      assertEq(_mainchainMockERC721.ownerOf(ids[i]), address(_mainchainGatewayV3));
    }
  }

  function hasDuplicate(uint256[] memory A) internal pure returns (bool) {
    if (A.length == 0) {
      return false;
    }
    unchecked {
      for (uint256 i = 0; i < A.length - 1; i++) {
        for (uint256 j = i + 1; j < A.length; j++) {
          if (A[i] == A[j]) {
            return true;
          }
        }
      }
    }

    return false;
  }
}
