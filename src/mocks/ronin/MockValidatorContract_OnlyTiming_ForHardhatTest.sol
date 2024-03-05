// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockValidatorContract_OnlyTiming_ForHardhatTest {
  event WrappedUpEpoch(uint256 newPeriod, uint256 newEpoch, bool periodEnding);
  event CurrentPeriodUpdated(uint256 previousPeriod, uint256 currentPeriod);

  uint256 public constant PERIOD_DURATION = 1 days;
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;
  /// @dev Mapping from epoch index => period index
  mapping(uint256 => uint256) internal _periodOf;

  constructor(uint256 __numberOfBlocksInEpoch) {
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
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

    setCurrentPeriod(_newPeriod);

    emit WrappedUpEpoch(_newPeriod, _nextEpoch, _periodEnding);
  }

  // function endEpoch() external {
  //   // _epochs.push(block.number);
  // 	uint nextEpoch = epochOf(block.number) + 1;
  // 	uint startBlockOfNextEpoch = nextEpoch * _numberOfBlocksInEpoch;
  // 	uint currPeriod = _computePeriod(block.timestamp);
  // 	for (uint i = block.number; i < startBlockOfNextEpoch; i++) {

  // 	}
  // }

  // function epochOf(uint256 _block) public view returns (uint256 _epoch) {
  //   for (uint256 _i = _epochs.length; _i > 0; _i--) {
  //     if (_block > _epochs[_i - 1]) {
  //       return _i;
  //     }
  //   }
  // }

  function epochEndingAt(uint256 _block) public view returns (bool) {
    // for (uint256 _i = 0; _i < _epochs.length; _i++) {
    //   if (_block == _epochs[_i]) {
    //     return true;
    //   }
    // }
    // return false;

    return (_block + 1) % _numberOfBlocksInEpoch == 0;
  }

  function getLastUpdatedBlock() external view returns (uint256) {
    return _lastUpdatedBlock;
  }

  function epochOf(uint256 _block) public view virtual returns (uint256) {
    return _block / _numberOfBlocksInEpoch + 1;
  }

  function tryGetPeriodOfEpoch(uint256 _epoch) external view returns (bool _filled, uint256 _periodNumber) {
    return (_epoch <= epochOf(block.number) || _periodOf[_epoch] > 0, _periodOf[_epoch]);
  }

  function isPeriodEnding() external view returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  function currentPeriod() public view virtual returns (uint256) {
    return _lastUpdatedPeriod;
  }

  function setCurrentPeriod(uint256 period) public {
    emit CurrentPeriodUpdated(_lastUpdatedPeriod, period);

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
