// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";

contract Migration__Governors_Config {
  Vm private constant vm = Vm(LibSharedAddress.VM);

  address[] internal governors = new address[](4);
  string[] internal pkOpSecretRefs = new string[](4);

  constructor() {
    // TODO: replace by address of the testnet governors
    governors[0] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[1] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[2] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[3] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    governors = LibArray.inplaceAscSort(governors);
  }
}
