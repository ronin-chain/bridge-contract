// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__MapToken_Usdc_Config {
  address constant _usdcRoninToken = address(0x067FBFf8990c58Ab90BaE3c97241C5d736053F77);
  // address constant _usdcMainchainToken = address(0x3429d03c6F7521AeC737a0BBF2E5ddcef2C3Ae31);

  // The decimal of USDC token is 18
  uint256 constant _highTierThreshold = 900 * 1e6;
  uint256 constant _lockedThreshold = 400 * 1e6;
  // The MAX_PERCENTAGE is 100_0000
  uint256 constant _unlockFeePercentages = 10; // 0.001%. Max percentage is 1e6 so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  uint256 constant _dailyWithdrawalLimit = 1000 * 1e6;

  // uint256 constant _usdcMinThreshold = 10 ether;

  address internal _governor = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // TODO: replace by address of the SV governor
}