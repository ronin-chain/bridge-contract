// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBridgeRewardEvents } from "./events/IBridgeRewardEvents.sol";

interface IBridgeReward is IBridgeRewardEvents {
  /**
   * @dev Configuration of gas stipend to ensure sufficient gas after London Hardfork.
   */
  function DEFAULT_ADDITION_GAS() external view returns (uint256);
  
  /**
   * @dev This function allows bridge operators to manually synchronize the reward for a given period length.
   * @param periodCount The length of the reward period for which synchronization is requested.
   */
  function syncRewardManual(uint256 periodCount) external;

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Invoke calculate and transfer reward to operators based on their performance.
   *
   * Requirements:
   * - This method is only called once each period.
   * - The caller must be the bridge tracking contract
   */
  function execSyncRewardAuto(uint256 currentPeriod) external;

  /**
   * @dev Returns the total amount of rewards that have been topped up in the contract.
   */
  function getTotalRewardToppedUp() external view returns (uint256);

  /**
   * @dev Returns the total reward amount scattered to the operators, excluding the slashed reward and failed-to-transfer reward.
   */
  function getTotalRewardScattered() external view returns (uint256);

  /**
   * @dev Getter for all bridge operators per period.
   */
  function getRewardPerPeriod() external view returns (uint256);

  /**
   * @dev External function to retrieve the latest rewarded period in the contract.
   */
  function getLatestRewardedPeriod() external view returns (uint256);

  /**
   * @dev Returns the claimed and slashed reward amount of the `operator`.
   */
  function getRewardInfo(address operator) external view returns (BridgeRewardInfo memory rewardInfo);

  /**
   * @dev Setter for all bridge operators per period.
   */
  function setRewardPerPeriod(uint256 rewardPerPeriod) external;
}
