// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

contract Migration__MapToken_Ygg_Config {
  MapTokenInfo _yggInfo;

  constructor () {
    _yggInfo.roninToken = address(0x1c306872bC82525d72Bf3562E8F0aA3f8F26e857);
    _yggInfo.mainchainToken = address(0x25f8087EAD173b73D6e8B84329989A8eEA16CF73);
    _yggInfo.minThreshold = 20 ether;
    _yggInfo.highTierThreshold = 1_000_000 ether;
    _yggInfo.lockedThreshold = 2_000_000 ether;
    _yggInfo.dailyWithdrawalLimit = 2_000_000 ether;
    _yggInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
