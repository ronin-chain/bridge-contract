// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeManagerThreshold
 */
interface IBridgeManagerThreshold {
  function setThreshold(uint256 num, uint256 denom) external;

  function getThreshold() external view returns (uint256 num, uint256 denom);

  function checkThreshold(uint256 voteWeight) external view returns (bool);
}
