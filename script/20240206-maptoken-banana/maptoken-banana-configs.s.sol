// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Migration__MapToken_Banana_Config {
  address constant _bananaRoninToken = address(0x1a89ecd466a23e98f07111b0510a2D6c1cd5E400);
  address constant _bananaMainchainToken = address(0x94e496474F1725f1c1824cB5BDb92d7691A4F03a);

  // The decimal of BANANA token is 18
  uint256 constant _highTierThreshold = 100_000 ether;
  uint256 constant _lockedThreshold = 600_000 ether;
  // The MAX_PERCENTAGE is 100_0000
  uint256 constant _unlockFeePercentages = 10; // 0.001%. Max percentage is 1e6 so 10 is 0.001% (`10 / 1e6 = 0.001 * 100`)
  uint256 constant _dailyWithdrawalLimit = 500_000 ether;

  uint256 constant _bananaMinThreshold = 10 ether;

  address internal _governor = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // TODO: replace by address of the SV governor
}
