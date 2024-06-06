// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import "../../utils/CommonErrors.sol";

abstract contract BridgeManagerQuorum is IQuorum, IdentityGuard, Initializable, HasContracts {
  struct BridgeManagerQuorumStorage {
    uint256 _nonce;
    uint256 _numerator;
    uint256 _denominator;
  }

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.BridgeManagerQuorumStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_BridgeManagerQuorumStorage = 0xf3019750f3837257cd40d215c9cc111e92586d2855a1e7e25d959613ed013f00;

  function __BridgeManagerQuorum_init_unchained(uint256 num, uint256 denom) internal onlyInitializing {
    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();
    $._nonce = 1;

    _setThreshold(num, denom);
  }

  function _getBridgeManagerQuorumStorage() private pure returns (BridgeManagerQuorumStorage storage $) {
    assembly {
      $.slot := $$_BridgeManagerQuorumStorage
    }
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 num, uint256 denom) external override onlyProxyAdmin {
    _setThreshold(num, denom);
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
  function _setThreshold(uint256 num, uint256 denom) internal virtual {
    if (num > denom || denom <= 1) revert ErrInvalidThreshold(msg.sig);

    BridgeManagerQuorumStorage storage $ = _getBridgeManagerQuorumStorage();

    uint256 prevNum = $._numerator;
    uint256 prevDenom = $._denominator;

    $._numerator = num;
    $._denominator = denom;

    emit ThresholdUpdated($._nonce++, num, denom, prevNum, prevDenom);
  }

  function _totalWeight() internal view virtual returns (uint256);
}
