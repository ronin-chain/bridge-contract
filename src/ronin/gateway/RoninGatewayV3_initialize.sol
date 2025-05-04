// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/ronin/gateway/RoninGatewayV3.sol";

contract RoninGatewayV3_initialize is RoninGatewayV3 {
  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    uint256 _numerator,
    uint256 _denominator,
    uint256 _trustedNumerator,
    uint256 _trustedDenominator,
    // _packedAddresses[0]: roninTokens
    // _packedAddresses[1]: mainchainTokens
    address[][2] calldata _packedAddresses,
    // _packedNumbers[0]: chainIds
    // _packedNumbers[1]: minimumThresholds
    uint256[][2] calldata _packedNumbers,
    TokenStandard[] calldata _standards,
    address bridgeManager,
    address bridgeTracking
  ) external virtual initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    _setThreshold(_numerator, _denominator);
    _setTrustedThreshold(_trustedNumerator, _trustedDenominator);
    if (_packedAddresses[0].length > 0) {
      _mapTokens(_packedAddresses[0], _packedAddresses[1], _packedNumbers[0], _standards);
      _setMinimumThresholds(_packedAddresses[0], _packedNumbers[1]);
    }
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManager);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTracking);
  }
}
