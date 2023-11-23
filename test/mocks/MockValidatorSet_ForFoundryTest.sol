// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

contract MockValidatorSet_ForFoundryTest {
  uint256 private _currentPeriod;

  function currentPeriod() external view returns (uint256) {
    return _currentPeriod;
  }

  function setCurrentPeriod(uint256 period) external {
    _currentPeriod = period;
  }
}
