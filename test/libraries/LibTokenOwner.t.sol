// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { TokenOwner, LibTokenOwner } from "@ronin/contracts/libraries/LibTokenOwner.sol";

contract LibTokenOwnerTest is Test {
  bytes32 _typeHash;

  function setUp() external {
    _typeHash = LibTokenOwner.OWNER_TYPE_HASH;
  }

  function testFuzz_hash(TokenOwner memory self) external {
    bytes32 expected = keccak256(abi.encode(_typeHash, self.addr, self.tokenAddr, self.chainId));
    bytes32 actual = LibTokenOwner.hash(self);
    assertEq(actual, expected, "hash mismatch");
  }
}
