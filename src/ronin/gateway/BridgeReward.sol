// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BridgeTrackingHelper } from "../../extensions/bridge-operator-governance/BridgeTrackingHelper.sol";
import { ContractType, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { RONTransferHelper } from "../../extensions/RONTransferHelper.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { IBridgeTracking } from "../../interfaces/bridge/IBridgeTracking.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { Math } from "../../libraries/Math.sol";
import { TUint256Slot } from "../../types/Types.sol";
import { ErrSyncTooFarPeriod, ErrInvalidArguments, ErrLengthMismatch, ErrUnauthorizedCall } from "../../utils/CommonErrors.sol";

contract BridgeReward is IBridgeReward, BridgeTrackingHelper, HasContracts, RONTransferHelper, Initializable {
  /// @dev Configuration of gas stipend to ensure sufficient gas after the London Hardfork
  uint256 public constant DEFAULT_ADDITION_GAS = 6200;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardInfo.slot") - 1
  bytes32 private constant $_REWARD_INFO = 0x518cfd198acbffe95e740cfce1af28a3f7de51f0d784893d3d72c5cc59d7062a;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardPerPeriod.slot") - 1
  TUint256Slot private constant $_REWARD_PER_PERIOD = TUint256Slot.wrap(0x90f7d557245e5dd9485f463e58974fa7cdc93c0abbd0a1afebb8f9640ec73910);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.latestRewardedPeriod.slot") - 1
  TUint256Slot private constant $_LATEST_REWARDED_PERIOD = TUint256Slot.wrap(0x2417f25874c1cdc139a787dd21df976d40d767090442b3a2496917ecfc93b619);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.totalRewardToppedUp.slot") - 1
  TUint256Slot private constant $_TOTAL_REWARDS_TOPPED_UP = TUint256Slot.wrap(0x9a8c9f129792436c37b7bd2d79c56132fc05bf26cc8070794648517c2a0c6c64);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.totalRewardScattered.slot") - 1
  TUint256Slot private constant $_TOTAL_REWARDS_SCATTERED = TUint256Slot.wrap(0x3663384f6436b31a97d9c9a02f64ab8b73ead575c5b6224fa0800a6bd57f62f4);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.maxRewardingPeriodCount.slot") - 1
  TUint256Slot private constant $_MAX_REWARDING_PERIOD_COUNT = TUint256Slot.wrap(0xaf260ffaff563b9407c1c5fe4aec2be8632142d158c44bb0ce4d471cb4883b8c);

  address private immutable _self;

  constructor() payable {
    _self = address(this);
    _disableInitializers();
  }

  function initialize(
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address bridgeSlashContract,
    address validatorSetContract,
    address dposGA,
    uint256 rewardPerPeriod
  ) external payable initializer {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlashContract);
    _setContract(ContractType.VALIDATOR, validatorSetContract);
    _setContract(ContractType.GOVERNANCE_ADMIN, dposGA);
    $_LATEST_REWARDED_PERIOD.store(type(uint256).max);
    _setRewardPerPeriod(rewardPerPeriod);
    _receiveRON();
  }

  /**
   * @dev Helper for running upgrade script, required to only revoked once by the DPoS's governance admin.
   * The following must be assured after initializing REP2:
   * ```
   *     {BridgeTracking}._lastSyncPeriod
   *     == {BridgeReward}.latestRewardedPeriod
   *     == {RoninValidatorSet}.currentPeriod()
   * ```
   */
  function initializeREP2() external onlyContract(ContractType.GOVERNANCE_ADMIN) {
    require(getLatestRewardedPeriod() == type(uint256).max, "already init rep 2");
    $_LATEST_REWARDED_PERIOD.store(IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod() - 1);
    _setContract(ContractType.GOVERNANCE_ADMIN, address(0));
  }

  /**
   * @dev The following must be assured after initializing V2:
   * ```
   *     {BridgeTracking}._lastSyncPeriod
   *     == {RoninValidatorSet}.currentPeriod()
   *     == {BridgeReward}.latestRewardedPeriod + 1
   * ```
   */
  function initializeV2() external reinitializer(2) {
    $_MAX_REWARDING_PERIOD_COUNT.store(5);
    $_LATEST_REWARDED_PERIOD.store(getLatestRewardedPeriod() - 1);
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function receiveRON() external payable {
    _receiveRON();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function syncRewardManual(uint256 periodCount) external {
    if (!_isBridgeOperator(msg.sender)) revert ErrUnauthorizedCall(msg.sig);
    uint256 currPd = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();

    _syncRewardBatch({ currPd: currPd, pdCount: periodCount });
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function execSyncRewardAuto(uint256 currentPeriod) external onlyContract(ContractType.BRIDGE_TRACKING) {
    _syncRewardBatch({ currPd: currentPeriod, pdCount: 0 });
  }

  /**
   * @dev Sync bridge reward for multiple periods, always assert `latestRewardedPeriod + periodCount < currentPeriod`.
   * @param pdCount Number of periods to settle reward. Leave this as 0 to auto calculate.
   */
  function _syncRewardBatch(uint256 currPd, uint256 pdCount) internal {
    uint256 lastRewardPd = getLatestRewardedPeriod();
    if (pdCount == 0) {
      uint toSettlePdCount;
      if (currPd > lastRewardPd) {
        toSettlePdCount = currPd - lastRewardPd - 1;
      }

      // Restrict number of period to reward in a transaction, to avoid consume too much gas
      pdCount = Math.min(toSettlePdCount, $_MAX_REWARDING_PERIOD_COUNT.load());
    }

    _assertPeriod({ currPd: currPd, pdCount: pdCount, lastRewardPd: lastRewardPd });

    address[] memory operators = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getBridgeOperators();
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));

    for (uint256 i = 0; i < pdCount; i++) {
      ++lastRewardPd;
      _settleReward({
        operators: operators,
        ballots: bridgeTrackingContract.getManyTotalBallots(lastRewardPd, operators),
        totalBallot: bridgeTrackingContract.totalBallot(lastRewardPd),
        totalVote: bridgeTrackingContract.totalVote(lastRewardPd),
        period: lastRewardPd
      });
    }
  }

  /**
   * @dev
   * Before the last valid rewarding:
   * |----------|------------------|------------------------------|-----------------|
   *             ^                  ^                              ^
   *                                                               Validator.current
   *             Reward.lastReward
   *                                Tracking.lastSync
   *                                Tracking.ballotInfo
   *                                Slash.slashInfo
   *
   *
   * After the last valid rewarding, the lastRewardedPeriod always slower than currentPeriod:
   * |----------|------------------|------------------------------|-----------------|
   *                                ^                              ^
   *                                                               Validator.current
   *                                Reward.lastReward
   *                                                               Tracking.lastSync
   *                                Tracking.ballotInfo
   *                                Slash.slashInfo
   */
  function _assertPeriod(uint256 currPd, uint256 pdCount, uint256 lastRewardPd) internal pure {
    if (pdCount == 0) revert ErrPeriodCountIsZero();

    // Not settle the period that already rewarded. This check may redundant as in the following assertion.
    // However, not increase much in gas, this is kept for obvious in error handling.
    if (currPd <= lastRewardPd + 1) revert ErrPeriodAlreadyRewarded(currPd, lastRewardPd);

    // Not settle the periods that not happen yet.
    if (currPd <= lastRewardPd + pdCount) revert ErrPeriodNotHappen(currPd, lastRewardPd, pdCount);
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getTotalRewardToppedUp() external view returns (uint256) {
    return $_TOTAL_REWARDS_TOPPED_UP.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getTotalRewardScattered() external view returns (uint256) {
    return $_TOTAL_REWARDS_SCATTERED.load();
  }

  /**
   * @dev Internal function to receive RON tokens as rewards and update the total topped-up rewards amount.
   */
  function _receiveRON() internal {
    // prevent transfer RON directly to logic contract
    if (address(this) == _self) revert ErrUnauthorizedCall(msg.sig);

    emit SafeReceived(msg.sender, $_TOTAL_REWARDS_TOPPED_UP.load(), msg.value);
    $_TOTAL_REWARDS_TOPPED_UP.addAssign(msg.value);
  }

  /**
   * @dev Internal function to synchronize and distribute rewards to bridge operators for a given period.
   * @param operators An array containing the addresses of bridge operators to receive rewards.
   * @param ballots An array containing the individual ballot counts for each bridge operator.
   * @param totalBallot The total number of available ballots for the period.
   * @param totalVote The total number of votes recorded for the period.
   * @param period The period for which the rewards are being synchronized.
   */
  function _settleReward(address[] memory operators, uint256[] memory ballots, uint256 totalBallot, uint256 totalVote, uint256 period) internal {
    uint256 numBridgeOperators = operators.length;
    if (numBridgeOperators != ballots.length) revert ErrLengthMismatch(msg.sig);

    uint256 rewardPerPeriod = getRewardPerPeriod();
    uint256[] memory slashedDurationList = _getSlashInfo(operators);
    // Validate should share the reward equally
    bool shouldShareEqually = _shouldShareEqually(totalBallot, totalVote, ballots);

    uint256 reward;
    bool shouldSlash;
    uint256 sumRewards;

    for (uint256 i; i < numBridgeOperators; i++) {
      (reward, shouldSlash) = _calcRewardAndCheckSlashedStatus({
        shouldShareEqually: shouldShareEqually,
        numBridgeOperators: numBridgeOperators,
        rewardPerPeriod: rewardPerPeriod,
        ballot: ballots[i],
        totalBallot: totalBallot,
        period: period,
        slashUntilPeriod: slashedDurationList[i]
      });

      bool scattered = _updateRewardAndTransfer({ period: period, operator: operators[i], reward: reward, shouldSlash: shouldSlash });
      sumRewards += (shouldSlash || !scattered) ? 0 : reward;
    }

    $_TOTAL_REWARDS_SCATTERED.addAssign(sumRewards);
    $_LATEST_REWARDED_PERIOD.store(period);
  }

  /**
   * @dev Returns whether should share the reward equally, in case of bridge tracking returns
   * informed data or there is no ballot in a day.
   *
   * Emit a {BridgeTrackingIncorrectlyResponded} event when in case of incorrect data.
   */
  function _shouldShareEqually(uint256 totalBallot, uint256 totalVote, uint256[] memory ballots) internal returns (bool shareEqually) {
    bool valid = _isValidBridgeTrackingResponse(totalBallot, totalVote, ballots);
    if (!valid) {
      emit BridgeTrackingIncorrectlyResponded();
    }

    return !valid || totalBallot == 0;
  }

  /**
   * @dev Internal function to calculate the reward for a bridge operator and check its slashing status.
   * @param shouldShareEqually A boolean indicating whether the reward should be shared equally among bridge operators.
   * @param numBridgeOperators The total number of bridge operators for proportional reward calculation.
   * @param rewardPerPeriod The total reward available for the period.
   * @param ballot The individual ballot count of the bridge operator for the period.
   * @param totalBallot The total number of available ballots for the period.
   * @param period The period for which the reward is being calculated.
   * @param slashUntilPeriod The period until which slashing is effective for the bridge operator.
   * @return reward The calculated reward for the bridge operator.
   * @return shouldSlash A boolean indicating whether the bridge operator should be slashed for the current period.
   */
  function _calcRewardAndCheckSlashedStatus(
    bool shouldShareEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot,
    uint256 period,
    uint256 slashUntilPeriod
  ) internal pure returns (uint256 reward, bool shouldSlash) {
    shouldSlash = _shouldSlashedThisPeriod(period, slashUntilPeriod);
    reward = _calcReward(shouldShareEqually, numBridgeOperators, rewardPerPeriod, ballot, totalBallot);
  }

  /**
   * @dev Internal function to check if a specific period should be considered as slashed based on the slash duration.
   */
  function _shouldSlashedThisPeriod(uint256 period, uint256 slashUntil) internal pure returns (bool) {
    return period <= slashUntil;
  }

  /**
   * @dev Internal function to calculate the reward for a bridge operator based on the provided parameters.
   * @param shouldShareEqually A boolean indicating whether the reward should be shared equally among bridge operators.
   * @param numBridgeOperators The total number of bridge operators for proportional reward calculation.
   * @param rewardPerPeriod The total reward available for the period.
   * @param ballot The individual ballot count of the bridge operator for the period.
   * @param totalBallot The total number of available ballots for the period.
   * @return reward The calculated reward for the bridge operator.
   */
  function _calcReward(
    bool shouldShareEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot
  ) internal pure returns (uint256 reward) {
    // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
    // Else shares the bridge operators reward proportionally
    reward = shouldShareEqually ? rewardPerPeriod / numBridgeOperators : (rewardPerPeriod * ballot) / totalBallot;
  }

  /**
   * @dev Transfer `reward` to a `operator` or only emit event based on the operator `slashed` status.
   */
  function _updateRewardAndTransfer(uint256 period, address operator, uint256 reward, bool shouldSlash) private returns (bool scattered) {
    BridgeRewardInfo storage _iRewardInfo = _getRewardInfo()[operator];

    if (shouldSlash) {
      _iRewardInfo.slashed += reward;
      emit BridgeRewardSlashed(period, operator, reward);
      return false;
    }

    if (_unsafeSendRONLimitGas({ recipient: payable(operator), amount: reward, gas: DEFAULT_ADDITION_GAS })) {
      _iRewardInfo.claimed += reward;
      emit BridgeRewardScattered(period, operator, reward);
      return true;
    } else {
      emit BridgeRewardScatterFailed(period, operator, reward);
      return false;
    }
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getRewardPerPeriod() public view returns (uint256) {
    return $_REWARD_PER_PERIOD.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getLatestRewardedPeriod() public view returns (uint256) {
    return $_LATEST_REWARDED_PERIOD.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getRewardInfo(address operator) external view returns (BridgeRewardInfo memory rewardInfo) {
    return _getRewardInfo()[operator];
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function setRewardPerPeriod(uint256 rewardPerPeriod) external onlyContract(ContractType.BRIDGE_MANAGER) {
    _setRewardPerPeriod(rewardPerPeriod);
  }

  /**
   * @dev Internal function for setting the total reward per period.
   * Emit an {UpdatedRewardPerPeriod} event after set.
   */
  function _setRewardPerPeriod(uint256 rewardPerPeriod) internal {
    $_REWARD_PER_PERIOD.store(rewardPerPeriod);
    emit UpdatedRewardPerPeriod(rewardPerPeriod);
  }

  /**
   * @dev Internal helper for querying slash info of a list of operators.
   */
  function _getSlashInfo(address[] memory operatorList) internal returns (uint256[] memory _slashedDuration) {
    return IBridgeSlash(getContract(ContractType.BRIDGE_SLASH)).getSlashUntilPeriodOf(operatorList);
  }

  /**
   * @dev Internal helper for querying whether an address is an operator.
   */
  function _isBridgeOperator(address operator) internal view returns (bool) {
    return IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).isBridgeOperator(operator);
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeRewardInfo.
   * @return rewardInfo the mapping from bridge operator => BridgeRewardInfo.
   */
  function _getRewardInfo() internal pure returns (mapping(address => BridgeRewardInfo) storage rewardInfo) {
    assembly ("memory-safe") {
      rewardInfo.slot := $_REWARD_INFO
    }
  }
}
