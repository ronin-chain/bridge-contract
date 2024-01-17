// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Deprecated Contracts
 * @dev These abstract contracts are deprecated and should not be used in new implementations.
 * They provide functionality related to various aspects of a smart contract but have been marked
 * as deprecated to indicate that they are no longer actively maintained or recommended for use.
 * The purpose of these contracts is to preserve the slots for already deployed contracts.
 */
contract HasBridgeDeprecated {
  /// @custom:deprecated Previously `_roninGatewayV3Contract` (non-zero value)
  address internal ______deprecatedBridge;
}

contract HasValidatorDeprecated {
  /// @custom:deprecated Previously `_validatorContract` (non-zero value)
  address internal ______deprecatedValidator;
}
