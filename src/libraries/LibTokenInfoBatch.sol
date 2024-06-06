// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "./LibTokenInfo.sol";

struct TokenInfoBatch {
  TokenStandard erc;
  uint256[] ids;
  uint256[] quantities;
}

/**
 * @dev Error indicating that the `transfer` has failed.
 * @param tokenInfo Info of the token including ERC standard, id or quantity.
 * @param to Receiver of the token value.
 * @param token Address of the token.
 */
error ErrTokenBatchCouldNotTransfer(TokenInfoBatch tokenInfo, address to, address token);

/**
 * @dev Error indicating that the `handleAssetIn` has failed.
 * @param tokenInfo Info of the token including ERC standard, id or quantity.
 * @param from Owner of the token value.
 * @param to Receiver of the token value.
 * @param token Address of the token.
 */
error ErrTokenBatchCouldNotTransferFrom(TokenInfoBatch tokenInfo, address from, address to, address token);

error ErrInvalidInfoWithStandard(TokenStandard);

library LibTokenInfoBatch {
  /**
   *
   *         VALIDATE
   *
   */

  /**
   * @dev Validates the token info.
   */
  function validate(TokenInfoBatch memory self, function (TokenInfoBatch memory) pure returns (bool) fCheck) internal pure {
    if (!fCheck(self)) {
      revert ErrInvalidInfoWithStandard(self.erc);
    }
  }

  function checkERC721Batch(TokenInfoBatch memory self) internal pure returns (bool res) {
    return self.erc == TokenStandard.ERC721 // Check ERC721
      && self.ids.length != 0 // Info must contain at least one id in the array
      && self.quantities.length == 0; // No requires quantity to save gas, because ERC-721 qty is always 1.
  }

  function checkERC1155Batch(TokenInfoBatch memory self) internal pure returns (bool res) {
    uint256 length = self.ids.length;

    if (
      // Check ERC1155
      // Info must contain at least one id in the array
      !(self.erc == TokenStandard.ERC1155 && self.ids.length != 0 && length == self.quantities.length) // Info must have same length for each pair id and quantity
    ) {
      return false;
    }

    // Each token id must have quantity
    for (uint256 i; i < length; ++i) {
      if (self.quantities[i] == 0) {
        return false;
      }
    }

    return true;
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
  function handleAssetIn(
    TokenInfoBatch memory self,
    address from,
    address token,
    function (TokenInfoBatch memory, address, address) returns (bool) fHandleAssetIn
  ) internal {
    if (!fHandleAssetIn(self, from, token)) revert ErrTokenBatchCouldNotTransferFrom(self, from, address(this), token);
  }

  function tryHandleAssetInERC721(TokenInfoBatch memory self, address from, address token) internal returns (bool) {
    return _tryTransferFromERC721Loop(token, from, address(this), self.ids);
  }

  function tryHandleAssetInERC1155(TokenInfoBatch memory self, address from, address token) internal returns (bool) {
    return _tryTransferERC1155Batch(token, from, address(this), self.ids, self.quantities);
  }

  /**
   *
   *      TRANSFER HELPERS
   *
   */

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
  function _tryTransferFromERC721Loop(address token, address from, address to, uint256[] memory ids) private returns (bool success) {
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
  function _tryTransferERC1155Batch(address token, address from, address to, uint256[] memory ids, uint256[] memory amounts) private returns (bool success) {
    (success,) = token.call(abi.encodeCall(IERC1155.safeBatchTransferFrom, (from, to, ids, amounts, new bytes(0))));
  }
}
