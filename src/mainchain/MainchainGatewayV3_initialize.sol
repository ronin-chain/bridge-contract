// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/mainchain/MainchainGatewayV3.sol";

contract MainchainGatewayV3_initialize is MainchainGatewayV3 {
  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    IWETH _wrappedToken,
    uint256 _roninChainId,
    uint256 _numerator,
    uint256 _highTierVWNumerator,
    uint256 _denominator,
    // _addresses[0]: mainchainTokens
    // _addresses[1]: roninTokens
    // _addresses[2]: withdrawalUnlockers
    address[][3] calldata _addresses,
    // _thresholds[0]: highTierThreshold
    // _thresholds[1]: lockedThreshold
    // _thresholds[2]: unlockFeePercentages
    // _thresholds[3]: dailyWithdrawalLimit
    uint256[][4] calldata _thresholds,
    TokenStandard[] calldata _standards,
    address bridgeManagerContract
  ) external initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    roninChainId = _roninChainId;

    _setWrappedNativeTokenContract(_wrappedToken);
    _updateDomainSeparator();
    _setThreshold(_numerator, _denominator);
    _setHighTierVoteWeightThreshold(_highTierVWNumerator, _denominator);
    _verifyThresholds();

    if (_addresses[0].length > 0) {
      // Map mainchain tokens to ronin tokens
      _mapTokens(_addresses[0], _addresses[1], _standards);
      // Sets thresholds based on the mainchain tokens
      _setHighTierThresholds(_addresses[0], _thresholds[0]);
      _setLockedThresholds(_addresses[0], _thresholds[1]);
      _setUnlockFeePercentages(_addresses[0], _thresholds[2]);
      _setDailyWithdrawalLimits(_addresses[0], _thresholds[3]);
    }

    // Grant role for withdrawal unlocker
    for (uint256 i; i < _addresses[2].length; i++) {
      _grantRole(WITHDRAWAL_UNLOCKER_ROLE, _addresses[2][i]);
    }

    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);

    (, address[] memory operators, uint96[] memory weights) = IBridgeManager(bridgeManagerContract).getFullBridgeOperatorInfos();

    uint96 totalWeight;
    for (uint i; i < operators.length; i++) {
      _operatorWeight[operators[i]] = weights[i];
      totalWeight += weights[i];
    }
    _totalOperatorWeight = totalWeight;
  }
}
