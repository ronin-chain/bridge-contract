// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library Uint96ArrayUtils {
  function extend(uint96[] memory a, uint96[] memory b) internal pure returns (uint96[] memory c) {
    uint256 lengthA = a.length;
    uint256 lengthB = b.length;
    unchecked {
      c = new uint96[](lengthA + lengthB);
    }
    uint256 i;
    for (; i < lengthA;) {
      c[i] = a[i];
      unchecked {
        ++i;
      }
    }
    for (uint256 j; j < lengthB;) {
      c[i] = b[j];
      unchecked {
        ++i;
        ++j;
      }
    }
  }
}
