// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

contract Migration__MapToken_Aperios_Config {
  MapTokenInfo _aperiosInfo;

  constructor() {
    _aperiosInfo.roninToken = address(0x7894b3088d069E70895EFfA4e8f7D2c243Fd04C1);
    _aperiosInfo.mainchainToken = address(0x95b4B8CaD3567B5d7EF7399C2aE1d7070692aB0D);
    _aperiosInfo.minThreshold = 10 ether;
    _aperiosInfo.highTierThreshold = 10_000_000 ether;
    _aperiosInfo.lockedThreshold = 40_000_000 ether;
    _aperiosInfo.dailyWithdrawalLimit = 30_000_000 ether;
    _aperiosInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
