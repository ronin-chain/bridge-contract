// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__20240409_GovernorsKey {
  function _loadGovernorPKs() internal pure returns (uint256[] memory res) {
    res = new uint256[](4);

    res[3] = 0xe3c1c8220c4ee4a6532d633296c3301db5397cff8a89a920da28f8bec97fcfb6;
    res[2] = 0xeb80bc77e3164b6bb3eebf7d5f96f2496eb292fab563377f247d2db5887395e0;
    res[0] = 0xed79936f720ac50b7c06138c6fd2d70abc19935de0fb347b0d782bdb6630e5a4;
    res[1] = 0x3b3eb1d442ea0d728bc069f9d6d47ba8dcc6c867800cdf42a12117cf231bba59;
  }
}
