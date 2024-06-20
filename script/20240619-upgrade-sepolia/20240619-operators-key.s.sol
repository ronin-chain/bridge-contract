// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__20240619_GovernorsKey {
  function _loadGovernorPKs() internal pure returns (uint256[] memory res) {
    res = new uint256[](4);

    res[0] = 0x00;
    res[1] = 0x00;
    res[2] = 0x00;
    res[3] = 0x00;
  }
}
