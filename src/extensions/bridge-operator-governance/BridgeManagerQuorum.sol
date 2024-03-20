// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";
import "../../utils/CommonErrors.sol";

abstract contract BridgeManagerQuorum is IQuorum, IdentityGuard {
  struct BridgeManagerQuorumStorage {
    uint256 _nonce;
    uint256 _numerator;
    uint256 _denominator;
  }

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.BridgeManagerQuorumStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_BridgeManagerQuorumStorage = 0xf3019750f3837257cd40d215c9cc111e92586d2855a1e7e25d959613ed013f00;

  function _getBridgeManagerQuorumStorage() private pure returns (BridgeManagerQuorumStorage storage $) {
    assembly {
      $.slot := $$_BridgeManagerQuorumStorage
    }
  }

  constructor(uint256 num, uint256 denom) {
    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();
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
    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();
    return ($._numerator, $._denominator);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 voteWeight) external view virtual returns (bool) {
    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();

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

    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();

    previousNum = $._numerator;
    previousDenom = $._denominator;

    $._numerator = numerator;
    $._denominator = denominator;

    emit ThresholdUpdated($._nonce++, numerator, denominator, previousNum, previousDenom);
  }

  function _totalWeight() internal view virtual returns (uint256);
}
