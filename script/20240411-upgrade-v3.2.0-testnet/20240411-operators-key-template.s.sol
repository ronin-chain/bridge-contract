// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__20240409_GovernorsKey {
  function _loadGovernorPKs() internal pure returns (uint256[] memory res) {
    res = new uint256[](1);

    res[0] = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
  }
}
