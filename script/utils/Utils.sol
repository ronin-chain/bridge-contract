// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Utils {
  function getEmptyAddressArray() internal pure returns (address[] memory arr) { }
  function getEmptyUintArray() internal pure returns (uint256[] memory arr) { }
  function getEmptyUint96Array() internal pure returns (uint96[] memory arr) { }

  function wrapUint96(uint96 val) internal pure returns (uint96[] memory arr) {
    arr = new uint96[](1);
    arr[0] = val;
  }

  function wrapUint(uint256 val1, uint256 val2) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](2);
    arr[0] = val1;
    arr[1] = val2;
  }

  function wrapUint(uint256 val) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = val;
  }

  function wrapAddress(address val1, address val2, address val3) internal pure returns (address[] memory arr) {
    arr = new address[](3);
    arr[0] = val1;
    arr[1] = val2;
    arr[2] = val3;
  }

  function wrapAddress(address val1, address val2) internal pure returns (address[] memory arr) {
    arr = new address[](2);
    arr[0] = val1;
    arr[1] = val2;
  }

  function wrapAddress(address val) internal pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = val;
  }

  function unwrapAddress(address[] memory arr) internal pure returns (address val) {
    val = arr[0];
  }
}
