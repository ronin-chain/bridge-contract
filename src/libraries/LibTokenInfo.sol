// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IWETH.sol";

enum TokenStandard {
  ERC20,
  ERC721,
  ERC721Batch,
  ERC1155
}

struct TokenInfo {
  TokenStandard erc;
  // For ERC20:  the id must be 0 and the quantity is larger than 0.
  // For ERC721: the quantity must be 0.
  uint256 id;
  uint256 quantity;
  uint256[] ids;
  uint256[] quantities;
}

library LibTokenInfo {
  /// @dev Error indicating that the provided information is invalid.
  error ErrInvalidInfo();

  /// @dev Error indicating that the minting of ERC20 tokens has failed.
  error ErrERC20MintingFailed();

  /// @dev Error indicating that the minting of ERC721 tokens has failed.
  error ErrERC721MintingFailed();

  /// @dev Error indicating that an unsupported standard is encountered.
  error ErrUnsupportedStandard();

  /**
   * @dev Error indicating that the `transfer` has failed.
   * @param tokenInfo Info of the token including ERC standard, id or quantity.
   * @param to Receiver of the token value.
   * @param token Address of the token.
   */
  error ErrTokenCouldNotTransfer(TokenInfo tokenInfo, address to, address token);

  /**
   * @dev Error indicating that the `transferFrom` has failed.
   * @param tokenInfo Info of the token including ERC standard, id or quantity.
   * @param from Owner of the token value.
   * @param to Receiver of the token value.
   * @param token Address of the token.
   */
  error ErrTokenCouldNotTransferFrom(TokenInfo tokenInfo, address from, address to, address token);

  /**
   *
   *        ROUTER
   *
   */
  function _isStandardSingle(TokenStandard standard) private pure returns (bool) {
    return standard == TokenStandard.ERC20 || standard == TokenStandard.ERC721;
  }

  function _isStandardBatch(TokenStandard standard) private pure returns (bool) {
    return standard == TokenStandard.ERC721Batch || standard == TokenStandard.ERC1155;
  }

  /**
   *
   *        HASH
   *
   */

  // keccak256("TokenInfo(uint8 erc,uint256 id,uint256 quantity)");
  bytes32 public constant INFO_TYPE_HASH_SINGLE = 0x1e2b74b2a792d5c0f0b6e59b037fa9d43d84fbb759337f0112fcc15ca414fc8d;

  // keccak256("TokenInfo(uint8 erc,uint256[] id,uint256[] quantity)");
  bytes32 public constant INFO_TYPE_HASH_BATCH = 0xe0d9a8bb18cfc29aa6e46b1293275ca79aeaaf28ac63b66dcb6ebce2f127f5a0;

  /**
   * @dev Returns token info struct hash.
   */
  function hash(TokenInfo memory self) internal pure returns (bytes32 digest) {
    if (_isStandardSingle(self.erc)) return _hashSingle(self);
    if (_isStandardBatch(self.erc)) return _hashBatch(self);
    revert ErrUnsupportedStandard();
  }

  function _hashSingle(TokenInfo memory self) internal pure returns (bytes32 digest) {
    // keccak256(abi.encode(INFO_TYPE_HASH_SINGLE, info.erc, info.id, info.quantity))
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, INFO_TYPE_HASH_SINGLE)
      mstore(add(ptr, 0x20), mload(self)) // info.erc
      mstore(add(ptr, 0x40), mload(add(self, 0x20))) // info.id
      mstore(add(ptr, 0x60), mload(add(self, 0x40))) // info.quantity
      digest := keccak256(ptr, 0x80)
    }
  }

  function _hashBatch(TokenInfo memory self) internal pure returns (bytes32 digest) {
    // keccak256(abi.encode(INFO_TYPE_HASH_BATCH, info.erc, info.ids, info.quantities))
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, INFO_TYPE_HASH_SINGLE)
      mstore(add(ptr, 0x20), mload(self)) // info.erc

      let ids := mload(add(self, 0x20)) // info.ids
      let idsHash := keccak256(add(ids, 32), mul(mload(ids), 32)) // keccak256(info.ids)
      mstore(add(ptr, 0x40), idsHash)

      let qtys := mload(add(self, 0x40)) // info.quantities
      let qtysHash := keccak256(add(qtys, 32), mul(mload(qtys), 32)) // keccak256(info.quantities)
      mstore(add(ptr, 0x60), qtysHash)

      digest := keccak256(ptr, 0x80)
    }
  }

  /**
   *
   *         VALIDATE
   *
   */

  /**
   * @dev Validates the token info.
   */
  function validate(TokenInfo memory self) internal pure {
    if (!(_validateERC20(self) || _validateERC721(self)) || _validateERC721Batch(self) || _validateERC1155(self)) {
      revert ErrInvalidInfo();
    }
  }

  function _validateERC20(TokenInfo memory self) private pure returns (bool) {
    return (self.erc == TokenStandard.ERC20 && self.quantity > 0 && self.id == 0);
  }

  function _validateERC721(TokenInfo memory self) private pure returns (bool) {
    return (self.erc == TokenStandard.ERC721 && self.quantity == 0);
  }

  function _validateERC721Batch(TokenInfo memory self) private pure returns (bool res) {
    uint256 length = self.ids.length;

    res = self.erc == TokenStandard.ERC721Batch && _validateBatch(self);

    for (uint256 i; i < length; ++i) {
      if (self.quantities[i] != 0) {
        return false;
      }
    }
  }

  function _validateERC1155(TokenInfo memory self) private pure returns (bool res) {
    uint256 length = self.ids.length;
    res = self.erc == TokenStandard.ERC1155 && _validateBatch(self);

    for (uint256 i; i < length; ++i) {
      if (self.quantities[i] == 0) {
        return false;
      }
    }
  }

  function _validateBatch(TokenInfo memory self) private pure returns (bool res) {
    return self.quantity == 0 && self.id == 0 && self.ids.length > 0 && self.quantities.length > 0
      && self.ids.length == self.quantities.length;
  }

  /**
   *
   *       TRANSFER
   *
   */

  /**
   * @dev Transfer asset from.
   *
   * Requirements:
   * - The `_from` address must approve for the contract using this library.
   *
   */
  function transferFrom(TokenInfo memory self, address from, address to, address token) internal {
    bool success;
    bytes memory data;
    if (self.erc == TokenStandard.ERC20) {
      (success, data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, self.quantity));
      success = success && (data.length == 0 || abi.decode(data, (bool)));
    } else if (self.erc == TokenStandard.ERC721) {
      // bytes4(keccak256("transferFrom(address,address,uint256)"))
      (success,) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, self.id));
    } else {
      revert ErrUnsupportedStandard();
    }

    if (!success) revert ErrTokenCouldNotTransferFrom(self, from, to, token);
  }

  /**
   * @dev Transfers ERC721 token and returns the result.
   */
  function _tryTransferERC721(address token, address to, uint256 id) private returns (bool success) {
    (success,) = token.call(abi.encodeWithSelector(IERC721.transferFrom.selector, address(this), to, id));
  }

  /**
   * @dev Transfers ERC20 token and returns the result.
   */
  function _tryTransferERC20(address token, address to, uint256 quantity) private returns (bool success) {
    bytes memory data;
    (success, data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, quantity));
    success = success && (data.length == 0 || abi.decode(data, (bool)));
  }

  /**
   * @dev Transfer assets from current address to `_to` address.
   */
  function transfer(TokenInfo memory self, address to, address token) internal {
    bool success;
    if (self.erc == TokenStandard.ERC20) {
      success = _tryTransferERC20(token, to, self.quantity);
    } else if (self.erc == TokenStandard.ERC721) {
      success = _tryTransferERC721(token, to, self.id);
    } else {
      revert ErrUnsupportedStandard();
    }

    if (!success) revert ErrTokenCouldNotTransfer(self, to, token);
  }

  /**
   * @dev Tries minting and transfering assets.
   *
   * @notice Prioritizes transfer native token if the token is wrapped.
   *
   */
  function handleAssetTransfer(TokenInfo memory self, address payable to, address token, IWETH wrappedNativeToken)
    internal
  {
    bool success;
    if (token == address(wrappedNativeToken)) {
      // Try sending the native token before transferring the wrapped token
      if (!to.send(self.quantity)) {
        wrappedNativeToken.deposit{ value: self.quantity }();
        transfer(self, to, token);
      }
    } else if (self.erc == TokenStandard.ERC20) {
      uint256 _balance = IERC20(token).balanceOf(address(this));

      if (_balance < self.quantity) {
        // bytes4(keccak256("mint(address,uint256)"))
        (success,) = token.call(abi.encodeWithSelector(0x40c10f19, address(this), self.quantity - _balance));
        if (!success) revert ErrERC20MintingFailed();
      }

      transfer(self, to, token);
    } else if (self.erc == TokenStandard.ERC721) {
      if (!_tryTransferERC721(token, to, self.id)) {
        // bytes4(keccak256("mint(address,uint256)"))
        (success,) = token.call(abi.encodeWithSelector(0x40c10f19, to, self.id));
        if (!success) revert ErrERC721MintingFailed();
      }
    } else {
      revert ErrUnsupportedStandard();
    }
  }
}