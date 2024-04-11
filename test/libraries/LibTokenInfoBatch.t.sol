// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { TokenStandard, TokenInfoBatch, LibTokenInfoBatch } from "@ronin/contracts/libraries/LibTokenInfoBatch.sol";

contract LibTokenInfoBatchTest is Test {
  function testConcrete_RevertIf_InvalidTokenInfoBatch() external {
    TokenInfoBatch memory self;
    self.erc = TokenStandard.ERC1155;
    self.ids = new uint256[](0);
    self.quantities = new uint256[](0);

    vm.expectRevert();
    LibTokenInfoBatch.validate(self, LibTokenInfoBatch.checkERC1155Batch);
  }
}
