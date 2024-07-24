// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__Governors_Config {
  address[] internal governors = new address[](4);
  uint256[] internal governorPks = new uint256[](4);

  constructor() {
    // TODO: replace by address of the testnet governors
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;
    // TODO: replace by private key of the testnet governors
    governorPks[3] = 0x0;
    governorPks[2] = 0x0;
    governorPks[0] = 0x0;
    governorPks[1] = 0x0;
  }
}
