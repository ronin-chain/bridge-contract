// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockValidatorContract_OnlyTiming_ForHardhatTest {
  uint256 public constant PERIOD_DURATION = 1 days;
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;
  uint256[] internal _epochs;

  constructor(uint256 __numberOfBlocksInEpoch) {
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
    _epochs.push(0);
  }

  function wrapUpEpoch() external payable {
    uint256 _newPeriod = _computePeriod(block.timestamp);
    bool _periodEnding = _isPeriodEnding(_newPeriod);

    uint256 _epoch = epochOf(block.number);
    uint256 _nextEpoch = _epoch + 1;

    if (_periodEnding) {
      _currentPeriodStartAtBlock = block.number + 1;
    }

    _periodOf[_nextEpoch] = _newPeriod;
    _lastUpdatedPeriod = _newPeriod;
  }

  function endEpoch() external {
    _epochs.push(block.number);
  }

  function epochOf(uint256 _block) public view returns (uint256 _epoch) {
    for (uint256 _i = _epochs.length; _i > 0; _i--) {
      if (_block > _epochs[_i - 1]) {
        return _i;
      }
    }
  }

  function epochEndingAt(uint256 _block) public view returns (bool) {
    for (uint256 _i = 0; _i < _epochs.length; _i++) {
      if (_block == _epochs[_i]) {
        return true;
      }
    }
    return false;
  }

  /// @dev Mapping from epoch index => period index
  mapping(uint256 => uint256) internal _periodOf;

  function getLastUpdatedBlock() external view returns (uint256) {
    return _lastUpdatedBlock;
  }

  // function epochOf(uint256 _block) public view virtual returns (uint256) {
  //   return _block / _numberOfBlocksInEpoch + 1;
  // }

  function tryGetPeriodOfEpoch(uint256 _epoch) external view returns (bool _filled, uint256 _periodNumber) {
    return (_epoch <= epochOf(block.number) || _periodOf[_epoch] > 0, _periodOf[_epoch]);
  }

  function isPeriodEnding() external view returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  function currentPeriod() public view virtual returns (uint256) {
    return _lastUpdatedPeriod;
  }

  function setCurrentPeriod(uint256 period) external {
    _lastUpdatedPeriod = period;
  }

  function currentPeriodStartAtBlock() public view returns (uint256) {
    return _currentPeriodStartAtBlock;
  }

  function numberOfBlocksInEpoch() public view virtual returns (uint256 _numberOfBlocks) {
    return _numberOfBlocksInEpoch;
  }

  function _isPeriodEnding(uint256 _newPeriod) internal view virtual returns (bool) {
    return _newPeriod > _lastUpdatedPeriod;
  }

  function _computePeriod(uint256 _timestamp) internal pure returns (uint256) {
    return _timestamp / PERIOD_DURATION;
  }
}
