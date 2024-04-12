// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LibArray
 * @dev A library for array-related utility functions in Solidity.
 */
library LibArray {
  /**
   * @dev Error indicating a length mismatch between two arrays.
   */
  error LengthMismatch();

  function repeat(uint256 value, uint256 length) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      arr[i] = value;
    }
  }

  function toSingletonArray(address self) internal pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = self;
  }

  function toSingletonArray(bytes memory self) internal pure returns (bytes[] memory arr) {
    arr = new bytes[](1);
    arr[0] = self;
  }

  function toSingletonArray(bytes32 self) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](1);
    arr[0] = self;
  }

  function toSingletonArray(uint256 self) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = self;
  }

  /**
   * @dev Returns whether or not there's a duplicate. Runs in O(n^2).
   * @param arr Array to search
   * @return Returns true if duplicate, false otherwise
   */
  function hasDuplicate(uint256[] memory arr) internal pure returns (bool) {
    if (arr.length == 0) return false;

    unchecked {
      for (uint256 i; i < arr.length - 1; ++i) {
        for (uint256 j = i + 1; j < arr.length; ++j) {
          if (arr[i] == arr[j]) return true;
        }
      }
    }

    return false;
  }

  /**
   * @dev Returns whether two arrays of addresses are equal or not.
   */
  function isEqual(uint256[] memory self, uint256[] memory other) internal pure returns (bool yes) {
    yes = hash(self) == hash(other);
  }

  /**
   * @dev Return the concatenated array from a and b.
   */
  function extend(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
    unchecked {
      uint256 lengthA = a.length;
      uint256 lengthB = b.length;
      c = new address[](lengthA + lengthB);

      uint256 i;
      for (; i < lengthA;) {
        c[i] = a[i];
        ++i;
      }
      for (uint256 j; j < lengthB;) {
        c[i] = b[j];
        ++i;
        ++j;
      }
    }
  }

  /**
   * @dev Converts an array of uint8 to an array of uint256.
   * @param self The array of uint8.
   * @return uint256s The resulting array of uint256s.
   */
  function toUint256s(uint8[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Converts an array of uint96 to an array of uint256.
   * @param self The array of uint96.
   * @return uint256s The resulting array of uint256s.
   */
  function toUint256s(uint96[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Down cast an array of uint256 to an array of uint8.
   * @param self The array of uint256.
   * @return uint8s The resulting array of uint256s.
   * This function will result in invalid data if value in array is greater than 255.
   * Use it as caution.
   */
  function toUint8sUnsafe(uint256[] memory self) internal pure returns (uint8[] memory uint8s) {
    assembly ("memory-safe") {
      uint8s := self
    }
  }

  function toUint96sUnsafe(uint256[] memory self) internal pure returns (uint96[] memory uint96s) {
    assembly ("memory-safe") {
      uint96s := self
    }
  }

  function toAddressesUnsafe(uint256[] memory self) internal pure returns (address[] memory addrs) {
    assembly ("memory-safe") {
      addrs := self
    }
  }

  /**
   * @dev Create an array of indices with provided range.
   * @param length The array size
   * @return data an array of indices
   */
  function arange(uint256 length) internal pure returns (uint256[] memory data) {
    data = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      data[i] = i;
    }
  }

  /**
   * @dev Converts an array of uint256 to an array of bytes32.
   * @param self The array of uint256.
   * @return bytes32s The resulting array of bytes32.
   */
  function toBytes32s(uint256[] memory self) internal pure returns (bytes32[] memory bytes32s) {
    assembly ("memory-safe") {
      bytes32s := self
    }
  }

  /**
   * @dev Hash dynamic size array
   * @param self The array of uint256
   * @return digest The hash result of the array
   */
  function hash(uint256[] memory self) internal pure returns (bytes32 digest) {
    assembly ("memory-safe") {
      digest := keccak256(add(self, 0x20), mul(mload(self), 0x20))
    }
  }

  /**
   * @dev Calculates the sum of an array of uint256 values.
   * @param data The array of uint256 values for which the sum is calculated.
   * @return result The sum of the provided array.
   */
  function sum(uint256[] memory data) internal pure returns (uint256 result) {
    assembly ("memory-safe") {
      // Load the length (first 32 bytes)
      let len := mload(data)
      let dataElementLocation := add(data, 0x20)

      // Iterate until the bound is not met.
      for { let end := add(dataElementLocation, mul(len, 0x20)) } lt(dataElementLocation, end) { dataElementLocation := add(dataElementLocation, 0x20) } {
        result := add(result, mload(dataElementLocation))
      }
    }
  }

  /**
   * @dev Converts an array of bytes32 to an array of uint256.
   * @param self The array of bytes32.
   * @return uint256s The resulting array of uint256.
   */
  function toUint256s(bytes32[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Converts an array of bool to an array of uint256.
   * @param self The array of bool.
   * @return uint256s The resulting array of uint256.
   */
  function toUint256s(bool[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Converts an array of uint64 to an array of uint256.
   * @param self The array of uint64.
   * @return uint256s The resulting array of uint256.
   */
  function toUint256s(uint64[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Converts an array of address to an array of uint256.
   * @param self The array of address.
   * @return uint256s The resulting array of uint256.
   */
  function toUint256s(address[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Sorts an array of uint256 values based on a corresponding array of values using the specified sorting mode.
   * @param self The array to be sorted.
   * @param values The corresponding array of values used for sorting.
   * @notice This function modify `self` and `values`
   * @return sorted The sorted array.
   */
  function inplaceSortByValue(uint256[] memory self, uint256[] memory values) internal pure returns (uint256[] memory sorted) {
    return inplaceQuickSortByValue(self, values);
  }

  /**
   * @dev Sorts an array of uint256 based on a corresponding array of values.
   * @param self The array to be sorted.
   * @param values The corresponding array of values used for sorting.
   * @notice This function modify `self` and `values`
   * @return sorted The sorted array.
   */
  function inplaceQuickSortByValue(uint256[] memory self, uint256[] memory values) internal pure returns (uint256[] memory sorted) {
    uint256 length = self.length;
    if (length != values.length) revert LengthMismatch();
    unchecked {
      if (length > 1) inplaceQuickSortByValue(self, values, 0, int256(length - 1));
    }

    assembly ("memory-safe") {
      sorted := self
    }
  }

  /**
   * @dev Internal function to perform quicksort on an array of uint256 values based on a corresponding array of values.
   * @param arr The array to be sorted.
   * @param values The corresponding array of values used for sorting.
   * @param left The left index of the subarray to be sorted.
   * @param right The right index of the subarray to be sorted.
   * @notice This function modify `arr` and `values`
   */
  function inplaceQuickSortByValue(uint256[] memory arr, uint256[] memory values, int256 left, int256 right) private pure {
    unchecked {
      if (left == right) return;
      int256 i = left;
      int256 j = right;
      uint256 pivot = values[uint256(left + right) >> 1];

      while (i <= j) {
        while (pivot > values[uint256(i)]) ++i;
        while (pivot < values[uint256(j)]) --j;

        if (i <= j) {
          (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
          (values[uint256(i)], values[uint256(j)]) = (values[uint256(j)], values[uint256(i)]);
          ++i;
          --j;
        }
      }

      if (left < j) inplaceQuickSortByValue(arr, values, left, j);
      if (i < right) inplaceQuickSortByValue(arr, values, i, right);
    }
  }
}
