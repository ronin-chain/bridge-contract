// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";

contract Migration__MapToken_WBTC_Config {
  MapTokenInfo _wbtcInfo;

  constructor() {
    _wbtcInfo.roninToken = address(0xb94C5fF7049F41BEa35d9f5F93DaCD91467BE669);
    _wbtcInfo.mainchainToken = address(0xc65DEC9c627e636E32E0c84BC08C30395f2dc4AD);
    _wbtcInfo.standard = TokenStandard.ERC20;
    // Todo: multiply with token's decimals.
    _wbtcInfo.minThreshold = 1 * 1e8;
    _wbtcInfo.highTierThreshold = 20 * 1e8;
    _wbtcInfo.lockedThreshold = 100 * 1e8;
    _wbtcInfo.dailyWithdrawalLimit = 110 * 1e8;
    _wbtcInfo.unlockFeePercentages = 10; // 0.001%. Max percentage is 100_0000, so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  }
}
