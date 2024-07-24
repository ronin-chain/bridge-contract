// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Vm } from "forge-std/Vm.sol";

contract Migration__Governors_Config {
  Vm private constant vm = Vm(LibSharedAddress.VM);

  address[] internal governors = new address[](4);
  uint256[] internal governorPks = new uint256[](4);
  string[] internal pkOpSecretRefs = new string[](4);

  constructor() {
    // TODO: replace by address of the testnet governors
    governors[0] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[1] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[2] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[3] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    pkOpSecretRefs[0] = "op://Tri X TuDo/6bxmktndkmp6nabsn2if4mznsi/password";
    pkOpSecretRefs[1] = "op://Tri X TuDo/6totodbje7qvffc56pgtuusnny/password";
    pkOpSecretRefs[2] = "op://Tri X TuDo/ouyrwjv2haolekgqlugl3vu2q4/password";
    pkOpSecretRefs[3] = "op://Tri X TuDo/qlsa3zdtl7lo7jpgd6bhm2pwv4/password";

    // TODO: replace by private key of the testnet governors
    governorPks[0] = _readOPRef(pkOpSecretRefs[0]);
    governorPks[1] = _readOPRef(pkOpSecretRefs[1]);
    governorPks[2] = _readOPRef(pkOpSecretRefs[2]);
    governorPks[3] = _readOPRef(pkOpSecretRefs[3]);

    for (uint256 i; i < governorPks.length; ++i) {
      require(vm.addr(governorPks[i]) == governors[i], "Governor PK does not match the governor address");
    }
  }

  function _readOPRef(string memory ref) private returns (uint256 pk) {
    string[] memory commandInput = new string[](3);

    commandInput[0] = "op";
    commandInput[1] = "read";
    commandInput[2] = ref;

    return vm.parseUint(vm.toString(vm.ffi(commandInput)));
  }
}
