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

  function toUint256s(uint8[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  function toUint8sUnsafe(uint256[] memory self) internal pure returns (uint8[] memory uint8s) {
    assembly ("memory-safe") {
      uint8s := self
    }
  }

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

  function hash(uint256[] memory data) internal pure returns (bytes32 digest) {
    assembly ("memory-safe") {
      digest := keccak256(add(data, 0x20), mload(data))
    }
  }

  /**
   * @dev Calculates the sum of an array of uint256 values.
   * @param data The array of uint256 values for which the sum is calculated.
   * @return result The sum of the provided array of uint256 values.
   */
  function sum(uint256[] memory data) internal pure returns (uint256 result) {
    assembly ("memory-safe") {
      // Load the length (first 32 bytes)
      let len := mload(data)
      let dataElementLocation := add(data, 0x20)

      // Iterate until the bound is not met.
      for { let end := add(dataElementLocation, mul(len, 0x20)) } lt(dataElementLocation, end) {
        dataElementLocation := add(dataElementLocation, 0x20)
      } { result := add(result, mload(dataElementLocation)) }
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
   * @dev Converts an array of uint64 to an array of uint256.
   * @param self The array of bytes32.
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
  function inlineSortByValue(uint256[] memory self, uint256[] memory values)
    internal
    pure
    returns (uint256[] memory sorted)
  {
    return inlineQuickSortByValue(self, values);
  }

  /**
   * @dev Sorts an array of uint256 based on a corresponding array of values.
   * @param self The array to be sorted.
   * @param values The corresponding array of values used for sorting.
   * @notice This function modify `self` and `values`
   * @return sorted The sorted array.
   */
  function inlineQuickSortByValue(uint256[] memory self, uint256[] memory values)
    internal
    pure
    returns (uint256[] memory sorted)
  {
    uint256 length = self.length;
    if (length != values.length) revert LengthMismatch();
    unchecked {
      if (length > 1) inlineQuickSortByValue(self, values, 0, int256(length - 1));
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
  function inlineQuickSortByValue(uint256[] memory arr, uint256[] memory values, int256 left, int256 right)
    private
    pure
  {
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

      if (left < j) inlineQuickSortByValue(arr, values, left, j);
      if (i < right) inlineQuickSortByValue(arr, values, i, right);
    }
  }
}
