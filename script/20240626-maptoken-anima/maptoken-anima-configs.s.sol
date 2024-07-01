// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

contract Migration__MapToken_Anima_Config {
  MapTokenInfo _animaInfo;

  constructor() {
    _animaInfo.roninToken = address(0x9F6a5cDc477e9f667d60424bFdb4E82089d9d72c);
    _animaInfo.mainchainToken = address(0xEd52E203D2D44FAaEA0D9fB6A40220A63c743c80);
    _animaInfo.minThreshold = 100 ether;
    _animaInfo.highTierThreshold = 20_000_000 ether;
    _animaInfo.lockedThreshold = 100_000_000 ether;
    _animaInfo.dailyWithdrawalLimit = 50_000_000 ether;
    _animaInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
