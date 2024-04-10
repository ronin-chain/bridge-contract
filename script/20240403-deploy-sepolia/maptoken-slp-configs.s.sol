// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__MapToken_Slp_Config {
  address constant _slpRoninToken = address(0x82f5483623D636BC3deBA8Ae67E1751b6CF2Bad2);

  // The decimal of SLP token is 0
  uint256 constant _highTierThreshold = 150_000;
  uint256 constant _lockedThreshold = 80_000;
  // The MAX_PERCENTAGE is 100_0000
  uint256 constant _unlockFeePercentages = 10; // 0.001%. Max percentage is 1e6 so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  uint256 constant _dailyWithdrawalLimit = 200_000;

  // uint256 constant _slpMinThreshold = 1000;

  address internal _governor = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // TODO: replace by address of the SV governor
}