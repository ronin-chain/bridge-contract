// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";

contract BridgeRewardHarness is BridgeReward {
  function exposed_syncRewardBatch(uint256 currPd, uint256 pdCount) external {
    _syncRewardBatch(currPd, pdCount);
  }

  function exposed_assertPeriod(uint256 currPd, uint256 pdCount, uint256 lastRewardPd) external pure {
    _assertPeriod(currPd, pdCount, lastRewardPd);
  }

  function exposed_settleReward(address[] calldata operators, uint256[] calldata ballots, uint256 totalBallot, uint256 totalVote, uint256 period) external {
    _settleReward(operators, ballots, totalBallot, totalVote, period);
  }
}
