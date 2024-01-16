// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";
import "../../utils/CommonErrors.sol";

abstract contract BridgeManagerQuorum is IQuorum, IdentityGuard {
  struct BridgeManagerConfigStorage {
    uint256 _nonce;
    uint256 _numerator;
    uint256 _denominator;
  }

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.BridgeManagerConfigStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_BridgeManagerConfigStorage = 0xa284664d8adf7d69a916362ec8082a90fd7c59679617cbcde6ef7ac0ead56500;

  function _getBridgeManagerConfigStorage() private pure returns (BridgeManagerConfigStorage storage $) {
    assembly {
      $.slot := $$_BridgeManagerConfigStorage
    }
  }

  constructor(uint256 num, uint256 denom) {
    BridgeManagerConfigStorage storage $ = _getBridgeManagerConfigStorage();
    $._nonce = 1;

    _setThreshold(num, denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 numerator, uint256 denominator) external override onlySelfCall returns (uint256, uint256) {
    return _setThreshold(numerator, denominator);
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() public view virtual returns (uint256 num, uint256 denom) {
    BridgeManagerConfigStorage storage $ = _getBridgeManagerConfigStorage();
    return ($._numerator, $._denominator);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 voteWeight) external view virtual returns (bool) {
    BridgeManagerConfigStorage storage $ = _getBridgeManagerConfigStorage();

    return voteWeight * $._denominator >= $._numerator * _totalWeight();
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(uint256 numerator, uint256 denominator) internal virtual returns (uint256 previousNum, uint256 previousDenom) {
    if (numerator > denominator) revert ErrInvalidThreshold(msg.sig);

    BridgeManagerConfigStorage storage $ = _getBridgeManagerConfigStorage();

    previousNum = $._numerator;
    previousDenom = $._denominator;

    $._numerator = numerator;
    $._denominator = denominator;

    emit ThresholdUpdated($._nonce++, numerator, denominator, previousNum, previousDenom);
  }

  function _totalWeight() internal view virtual returns (uint256);
}
