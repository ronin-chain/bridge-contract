// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";

contract Migration__MapToken_WBTC_Config {
  MapTokenInfo _wbtcInfo;

  constructor() {
    _wbtcInfo.roninToken = address(0x484B66c2DEa0A6F3De86Cf69A36423bb9b3eA6b3);
    _wbtcInfo.mainchainToken = address(0x5F258c450e177f3e07a874BF102e227d373F5e8B);
    _wbtcInfo.standard = TokenStandard.ERC20;
    _wbtcInfo.minThreshold = 100 ether;
    _wbtcInfo.highTierThreshold = 20_000_000 ether;
    _wbtcInfo.lockedThreshold = 100_000_000 ether;
    _wbtcInfo.dailyWithdrawalLimit = 50_000_000 ether;
    _wbtcInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
