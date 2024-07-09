// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";

contract Migration__MapToken_WBTC_Config {
  MapTokenInfo _wbtcInfo;

  constructor() {
    _wbtcInfo.roninToken = address(0x88A0a5229D17765043CE5643B1A02434b09D74ca);
    _wbtcInfo.mainchainToken = address(0x262De5Be1C78930FB3b31361A4e0fa0b00A48C72);
    _wbtcInfo.standard = TokenStandard.ERC20;
    _wbtcInfo.minThreshold = 1 ether;
    _wbtcInfo.highTierThreshold = 20 ether;
    _wbtcInfo.lockedThreshold = 100 ether;
    _wbtcInfo.dailyWithdrawalLimit = 110 ether;
    _wbtcInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
