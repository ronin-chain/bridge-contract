// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct MapTokenInfo {
  address roninToken;
  address mainchainToken;

  // Config on mainchain
  uint256 minThreshold;

  // Config on ronin chain
  uint256 highTierThreshold;
  uint256 lockedThreshold;
  uint256 dailyWithdrawalLimit;
  uint256 unlockFeePercentages;
}
