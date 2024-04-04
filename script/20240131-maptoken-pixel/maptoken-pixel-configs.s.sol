// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__MapToken_Pixel_Config {
  address constant _pixelRoninToken = address(0x7EAe20d11Ef8c779433Eb24503dEf900b9d28ad7);
  address constant _pixelMainchainToken = address(0x3429d03c6F7521AeC737a0BBF2E5ddcef2C3Ae31);

  address constant _farmlandRoninToken = address(0xF083289535052E8449D69e6dc41c0aE064d8e3f6);
  address constant _farmlandMainchainToken = address(0x5C1A0CC6DAdf4d0fB31425461df35Ba80fCBc110);

  // The decimal of PIXEL token is 18
  uint256 constant _highTierThreshold = 100_000_000 ether;
  uint256 constant _lockedThreshold = 400_000_000 ether;
  // The MAX_PERCENTAGE is 100_0000
  uint256 constant _unlockFeePercentages = 10; // 0.001%. Max percentage is 1e6 so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  uint256 constant _dailyWithdrawalLimit = 300_000_000 ether;

  uint256 constant _pixelMinThreshold = 10 ether;

  address constant _aggMainchainToken = address(0xFB0489e9753B045DdB35e39c6B0Cc02EC6b99AC5);
  uint256 constant _aggMinThreshold = 1000 ether;

  address internal _governor = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // TODO: replace by address of the SV governor
}
