// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";

library LibRandom {
  Vm private constant vm = Vm(LibSharedAddress.VM);

  function generateSeed() internal returns (uint256) {
    return uint256(keccak256(abi.encode(vm.unixTime())));
  }

  function randomize(uint256 seed, uint256 min, uint256 max) internal pure returns (uint256 r) {
    r = Math.max(r, min);
    r = Math.min(seed, max);
  }

  function createRandomAddresses(uint256 seed, uint256 amount) internal returns (address[] memory addrs) {
    addrs = new address[](amount);

    for (uint256 i; i < amount;) {
      seed = uint256(keccak256(abi.encode(seed)));
      addrs[i] = vm.addr(seed);
      vm.etch(addrs[i], abi.encode());
      vm.deal(addrs[i], 1 ether);

      unchecked {
        ++i;
      }
    }
  }

  function createRandomNumbers(uint256 seed, uint256 amount, uint256 min, uint256 max) internal pure returns (uint256[] memory nums) {
    uint256 r;
    nums = new uint256[](amount);

    for (uint256 i; i < amount;) {
      r = randomize(seed, min, max);
      nums[i] = r;
      seed = r;

      unchecked {
        ++i;
      }
    }
  }
}
