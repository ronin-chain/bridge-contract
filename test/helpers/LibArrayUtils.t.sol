// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibArrayUtils {
  function sum(bool[] memory arr) internal pure returns (uint256 total) {
    uint256 length = arr.length;
    for (uint256 i; i < length; ) {
      if (arr[i]) total++;
      unchecked {
        ++i;
      }
    }
  }

  function sum(uint256[] memory arr) internal pure returns (uint256 total) {
    uint256 length = arr.length;
    for (uint256 i; i < length; ) {
      total += arr[i];
      unchecked {
        ++i;
      }
    }
  }

  function sum(uint96[] memory arr) internal pure returns (uint256 total) {
    uint256[] memory arr256;
    assembly {
      arr256 := arr
    }

    return sum(arr256);
  }

  function concat(uint96[] memory a, uint96[] memory b) internal pure returns (uint96[] memory c) {
    c = new uint96[](a.length + b.length);

    uint i;
    for (; i < a.length; i++) {
      c[i] = a[i];
    }

    for (uint j; j < b.length; ) {
      c[i] = b[j];
      ++i;
      ++j;
    }
  }

  function concat(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
    c = new address[](a.length + b.length);

    uint i;
    for (; i < a.length; i++) {
      c[i] = a[i];
    }

    for (uint j; j < b.length; ) {
      c[i] = b[j];
      ++i;
      ++j;
    }
  }
}
