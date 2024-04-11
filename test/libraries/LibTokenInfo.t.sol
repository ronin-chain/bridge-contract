// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { TokenStandard, TokenInfo, LibTokenInfo } from "@ronin/contracts/libraries/LibTokenInfo.sol";

contract LibTokenInfoTest is Test {
  bytes32 typeHash;

  function setUp() external {
    typeHash = LibTokenInfo.INFO_TYPE_HASH_SINGLE;
  }

  function testFuzz_hash(uint8 _erc, uint256 id, uint256 quantity) external {
    _erc = uint8(_bound(_erc, 0, 2));
    TokenStandard erc;
    assembly {
      erc := _erc
    }
    TokenInfo memory self = TokenInfo({ erc: erc, id: id, quantity: quantity });
    bytes32 hash = typeHash;
    assertTrue(hash != 0, "typeHash is zero");
    bytes32 expected = keccak256(abi.encode(hash, self.erc, self.id, self.quantity));
    bytes32 actual = LibTokenInfo.hash(self);
    assertEq(actual, expected, "hash mismatch");
  }
}
