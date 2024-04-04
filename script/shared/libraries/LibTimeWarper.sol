// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm } from "forge-std/Vm.sol";
import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";

library LibTimeWarper {
  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig private constant config = IGeneralConfig(LibSharedAddress.CONFIG);
  uint256 private constant PERIOD_DURATION = 1 days;
  uint256 private constant TIMESTAMP_PER_BLOCK = 3;
  uint256 private constant NUMBER_OF_BLOCKS_IN_EPOCH = 200;

  function warpNextPeriod() internal {
    uint256 epochEndingBlockNumber = block.number + (NUMBER_OF_BLOCKS_IN_EPOCH - 1) - (block.number % NUMBER_OF_BLOCKS_IN_EPOCH);
    uint256 nextDayTimestamp = block.timestamp + 1 days;

    // fast forward to next day
    vm.warp(nextDayTimestamp);
    vm.roll(epochEndingBlockNumber);
  }

  function isPeriodEnding() internal view returns (bool) {
    return block.number % NUMBER_OF_BLOCKS_IN_EPOCH == NUMBER_OF_BLOCKS_IN_EPOCH - 1;
  }

  function epochOf(uint256 blockNumber) internal pure returns (uint256) {
    return blockNumber / NUMBER_OF_BLOCKS_IN_EPOCH + 1;
  }

  function computePeriod(uint256 timestamp) internal pure returns (uint256) {
    return timestamp / PERIOD_DURATION;
  }

  function warp(uint256 numPeriod) internal {
    for (uint256 i; i < numPeriod; i++) {
      warpNextPeriod();
    }
  }
}
