// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "../interfaces/IWETH.sol";

enum Mode {
  Single,
  Batch
}

enum TokenStandard {
  ERC20,
  ERC721,
  ERC1155
}

struct TokenInfo {
  TokenStandard erc;
  Mode mode;
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

  /// @dev Error indicating that the transfer of ERC1155 tokens has failed.
  error ErrERC1155TransferFailed();

  /// @dev Error indicating that the mint of ERC1155 tokens in batch has failed.
  error ErrERC1155MintBatchFailed();

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
   * @dev Error indicating that the `handleAssetIn` has failed.
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
  function _isModeSingle(Mode mode) private pure returns (bool) {
    return mode == Mode.Single;
  }

  function _isModeBatch(Mode mode) private pure returns (bool) {
    return mode == Mode.Batch;
  }

  /**
   *
   *        HASH
   *
   */

  // keccak256("TokenInfo(uint8 erc,uint256 id,uint256 quantity)");
  bytes32 internal constant INFO_TYPE_HASH_SINGLE = 0x1e2b74b2a792d5c0f0b6e59b037fa9d43d84fbb759337f0112fcc15ca414fc8d;

  // keccak256("TokenInfo(uint8 erc,uint256[] ids,uint256[] quantities)");
  bytes32 internal constant INFO_TYPE_HASH_BATCH = 0xe0d9a8bb18cfc29aa6e46b1293275ca79aeaaf28ac63b66dcb6ebce2f127f5a0;

  /**
   * @dev Returns token info struct hash.
   */
  function hash(TokenInfo memory self) internal pure returns (bytes32 digest) {
    if (_isModeSingle(self.mode)) return _hashSingle(self);
    if (_isModeBatch(self.mode)) return _hashBatch(self);
    revert ErrUnsupportedStandard();
  }

  function _hashSingle(TokenInfo memory self) internal pure returns (bytes32 digest) {
    // return keccak256(abi.encode(INFO_TYPE_HASH_SINGLE, self.erc, self.id, self.quantity));
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(ptr, INFO_TYPE_HASH_SINGLE)
      mstore(add(ptr, 0x20), mload(self)) // info.erc
      mstore(add(ptr, 0x40), mload(add(self, 0x20))) // info.id
      mstore(add(ptr, 0x60), mload(add(self, 0x40))) // info.quantity
      digest := keccak256(ptr, 0x80)
    }
  }

  function _hashBatch(TokenInfo memory self) internal pure returns (bytes32 digest) {
    bytes32 idsHash = keccak256(abi.encodePacked(self.ids));
    bytes32 qtysHash = keccak256(abi.encodePacked(self.quantities));

    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(ptr, INFO_TYPE_HASH_SINGLE)
      mstore(add(ptr, 0x20), mload(self)) // info.erc
      mstore(add(ptr, 0x40), idsHash)
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
    if (!_validate(self)) revert ErrInvalidInfo();
  }

  function _validate(TokenInfo memory self) private pure returns (bool passed) {
    if (_isModeSingle(self.mode)) {
      return _validateERC20(self) || _validateERC721(self) || _validateERC1155(self);
    }

    if (_isModeBatch(self.mode)) {
      return _validateBatch(self) && (_validateERC721Batch(self) || _validateERC1155Batch(self));
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
    res = self.erc == TokenStandard.ERC721;

    for (uint256 i; i < length; ++i) {
      if (self.quantities[i] != 0) {
        return false;
      }
    }
  }

  function _validateERC1155Batch(TokenInfo memory self) private pure returns (bool res) {
    uint256 length = self.ids.length;
    res = self.erc == TokenStandard.ERC1155;

    for (uint256 i; i < length; ++i) {
      if (self.quantities[i] == 0) {
        return false;
      }
    }
  }

  function _validateBatch(TokenInfo memory self) private pure returns (bool res) {
    return self.quantity == 0 && self.id == 0 && self.ids.length > 0 && self.ids.length == self.quantities.length;
  }

  /**
   *
   *       TRANSFER IN/OUT METHOD
   *
   */

  /**
   * @dev Transfer asset in.
   *
   * Requirements:
   * - The `_from` address must approve for the contract using this library.
   *
   */
  function handleAssetIn(TokenInfo memory self, address from, address token) internal {
    (bool supported, bool success) = _handleAssetIn(self, from, token);
    if (!supported) revert ErrUnsupportedStandard();
    if (!success) revert ErrTokenCouldNotTransferFrom(self, from, address(this), token);
  }

  function _handleAssetIn(TokenInfo memory self, address from, address token)
    private
    returns (bool supported, bool success)
  {
    if (_isModeSingle(self.mode)) {
      if (self.erc == TokenStandard.ERC20) {
        bytes memory data;
        (success, data) =
          token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), self.quantity));
        success = success && (data.length == 0 || abi.decode(data, (bool)));
        return (true, success);
      }

      if (self.erc == TokenStandard.ERC721) {
        success = _tryTransferFromERC721(token, from, address(this), self.id);
        return (true, success);
      }

      return (false, false);
    }

    if (_isModeBatch(self.mode)) {
      if (self.erc == TokenStandard.ERC721) {
        success = _tryTransferFromERC721Loop(token, from, address(this), self.ids);
        return (true, success);
      }

      if (self.erc == TokenStandard.ERC1155) {
        success = _tryTransferERC1155Batch(token, from, address(this), self.ids, self.quantities);
        return (true, success);
      }

      return (false, false);
    }

    return (false, false);
  }

  /**
   * @dev Tries transfer assets out, or mint the assets if cannot transfer.
   *
   * @notice Prioritizes transfer native token if the token is wrapped.
   *
   */
  function handleAssetOut(TokenInfo memory self, address payable to, address token, IWETH wrappedNativeToken) internal {
    if (_isModeSingle(self.mode)) {
      if (token == address(wrappedNativeToken)) {
        // Try sending the native token before transferring the wrapped token
        if (!to.send(self.quantity)) {
          wrappedNativeToken.deposit{ value: self.quantity }();
          _transferTokenOut(self, to, token);
        }

        return;
      }

      if (self.erc == TokenStandard.ERC20) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < self.quantity) {
          if (!_tryMintERC20(token, address(this), self.quantity - balance)) revert ErrERC20MintingFailed();
        }

        _transferTokenOut(self, to, token);

        return;
      }

      if (self.erc == TokenStandard.ERC721) {
        if (!_tryTransferOutOrMintERC721(token, to, self.id)) {
          revert ErrERC721MintingFailed();
        }

        return;
      }
    }

    if (self.erc == TokenStandard.ERC721) {
      for (uint256 i; i < self.ids.length; ++i) {
        uint256 id = self.ids[i];
        if (!_tryTransferOutOrMintERC721(token, to, id)) revert ErrERC721MintingFailed();
      }

      return;
    }

    if (_isModeBatch(self.mode)) {
      if (self.erc == TokenStandard.ERC1155) {
        (uint256[] memory toMintIds, uint256[] memory toMintAmounts) =
          _calcLackBalancesERC1155(address(this), token, self.ids, self.quantities);

        if (toMintIds.length > 0) {
          if (!_tryMintERC1155Batch(token, address(this), toMintIds, toMintAmounts)) revert ErrERC1155MintBatchFailed();
        }

        if (!_tryTransferERC1155Batch(token, address(this), to, self.ids, self.quantities)) {
          revert ErrERC1155TransferFailed();
        }

        return;
      }
    }

    revert ErrUnsupportedStandard();
  }

  /**
   *
   *      TRANSFER HELPERS
   *
   */

  /**
   * @dev Transfer assets from current address to `_to` address.
   */
  function _transferTokenOut(TokenInfo memory self, address to, address token) private {
    bool success;
    if (self.erc == TokenStandard.ERC20) {
      success = _tryTransferERC20(token, to, self.quantity);
    } else if (self.erc == TokenStandard.ERC721) {
      success = _tryTransferFromERC721(token, address(this), to, self.id);
    } else {
      revert ErrUnsupportedStandard();
    }

    if (!success) revert ErrTokenCouldNotTransfer(self, to, token);
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
   * @dev Mints ERC20 token and returns the result.
   */
  function _tryMintERC20(address token, address to, uint256 quantity) private returns (bool success) {
    // bytes4(keccak256("mint(address,uint256)"))
    (success,) = token.call(abi.encodeWithSelector(0x40c10f19, to, quantity));
  }

  /**
   * @dev Transfers the ERC721 token out. If the transfer failed, mints the ERC721.
   * @return success Returns `false` if both transfer and mint are failed.
   */
  function _tryTransferOutOrMintERC721(address token, address to, uint256 id) private returns (bool success) {
    success = _tryTransferFromERC721(token, address(this), to, id);
    if (!success) {
      return _tryMintERC721(token, to, id);
    }
  }

  /**
   * @dev Transfers ERC721 token and returns the result.
   */
  function _tryTransferFromERC721(address token, address from, address to, uint256 id) private returns (bool success) {
    (success,) = token.call(abi.encodeWithSelector(IERC721.transferFrom.selector, from, to, id));
  }

  /**
   * @dev Transfers ERC721 token in a loop and returns the result.
   *
   * If there is fail when transfer one `id`, the loop will break early to save gas.
   * Consumer of this method should revert the transaction if receive `false` success status.
   */
  function _tryTransferFromERC721Loop(address token, address from, address to, uint256[] memory ids)
    private
    returns (bool success)
  {
    for (uint256 i; i < ids.length; ++i) {
      if (!_tryTransferFromERC721(token, from, to, ids[i])) {
        return false; // Break early if send fails
      }
    }

    return true;
  }

  /**
   * @dev Mints ERC721 token and returns the result.
   */
  function _tryMintERC721(address token, address to, uint256 id) private returns (bool success) {
    // bytes4(keccak256("mint(address,uint256)"))
    (success,) = token.call(abi.encodeWithSelector(0x40c10f19, to, id));
  }

  /**
   * @dev Transfers ERC1155 token in and returns the result.
   */
  function _tryTransferERC1155(address token, address to, uint256 id, uint256 amount) private returns (bool success) {
    (success,) = token.call(abi.encodeCall(IERC1155.safeTransferFrom, (address(this), to, id, amount, new bytes(0))));
  }

  /**
   * @dev Transfers ERC1155 token in and returns the result.
   */
  function _tryTransferERC1155Batch(
    address token,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) private returns (bool success) {
    (success,) = token.call(abi.encodeCall(IERC1155.safeBatchTransferFrom, (from, to, ids, amounts, new bytes(0))));
  }

  /**
   * @dev Mints ERC1155 token in batch and returns the result.
   */
  function _tryMintERC1155Batch(address token, address to, uint256[] memory ids, uint256[] memory amounts)
    private
    returns (bool success)
  {
    (success,) = token.call(abi.encodeCall(ERC1155PresetMinterPauser.mintBatch, (to, ids, amounts, new bytes(0))));
  }

  /**
   *
   *      OTHER HELPERS
   *
   */

  /**
   * @dev Gets ERC1155 balance of token `ids` for user `who`, then compare with the `requiredAmounts`. Returns list of `ids_` that have `lackAmounts_` at least 1.
   */
  function _calcLackBalancesERC1155(address who, address token, uint256[] memory ids, uint256[] memory requiredAmounts)
    private
    view
    returns (uint256[] memory ids_, uint256[] memory lackAmounts_)
  {
    uint256 length = ids.length;
    address[] memory whos = new address[](length);
    ids_ = new uint256[](length);
    lackAmounts_ = new uint256[](length);

    for (uint256 i; i < length; i++) {
      whos[i] = address(who);
    }

    // Get balance of all ids belongs to `who`
    uint256[] memory balances = IERC1155(token).balanceOfBatch(whos, ids);

    uint256 count = 0;

    // Find the ids that lack of balance
    for (uint256 i; i < length; i++) {
      if (requiredAmounts[i] > balances[i]) {
        lackAmounts_[count] = requiredAmounts[i] - balances[i];
        ids_[count++] = ids[i];
      }
    }

    assembly {
      mstore(ids_, count)
      mstore(lackAmounts_, count)
    }
  }
}
