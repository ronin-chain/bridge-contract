// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TokenStandard } from "src/libraries/LibTokenInfo.sol";

abstract contract FunctionRestrictable {
  /// @custom:storage-location erc7201:ronin.bridge.FunctionRestrictable
  struct FunctionalRestrictableStorage {
    mapping(bytes4 fnSig => uint8 bitmap) _enumBitmap;
  }

  /// @dev Emit when a function is paused.
  event Restricted(address indexed by, bytes4 indexed fnSig, uint8 enumBitmap);
  /// @dev Emit when a function is unpaused.
  event UnRestricted(address indexed by, bytes4 indexed fnSig);

  /// @dev Error when the function is restricted for specific standard.
  error ErrRestricted(bytes4 fnSig, TokenStandard standard);

  /**
   * @dev Modifier to check if the caller is authorized.
   */
  modifier onlyAuth() {
    _requireAuth();
    _;
  }

  /**
   * @dev Restrict a specific function with standard bitmap.
   *
   * Requirement:
   * - The caller must be authorized.
   *
   * Emits a {Restricted} event if `enumBitmap` is not 0.
   * Emits a {UnRestricted} event if `enumBitmap` is 0.
   *
   * +-------------------------+---------+------------+------------+------------+------------+------------+---------+--------+-------+
   * |          Case           | Decimal | Unused Bit | Unused Bit | Unused Bit | Unused Bit | Unused Bit | ERC1155 | ERC721 | ERC20 |
   * +-------------------------+---------+------------+------------+------------+------------+------------+---------+--------+-------+
   * | Allow All               |       0 |          0 |          0 |          0 |          0 |          0 |       0 |      0 |     0 |
   * | Forbid ERC20            |       1 |          0 |          0 |          0 |          0 |          0 |       0 |      0 |     1 |
   * | Forbid ERC721           |       2 |          0 |          0 |          0 |          0 |          0 |       0 |      1 |     0 |
   * | Forbid ERC20 && ERC721  |       3 |          0 |          0 |          0 |          0 |          0 |       0 |      1 |     1 |
   * | Forbid ERC1155 && ERC20 |       5 |          0 |          0 |          0 |          0 |          0 |       1 |      0 |     1 |
   * | Forbid All              |     255 |          1 |          1 |          1 |          1 |          1 |       1 |      1 |     1 |
   * | Forbid All              |       7 |          0 |          0 |          0 |          0 |          0 |       1 |      1 |     1 |
   * +-------------------------+---------+------------+------------+------------+------------+------------+---------+--------+-------+
   *
   * @param fnSig The function signature to restrict.
   * @param enumBitmap The bitmap of the standard to restrict.
   */
  function restrict(bytes4 fnSig, uint8 enumBitmap) external onlyAuth {
    _restrict(fnSig, enumBitmap);
  }

  /**
   * @dev Check if the function is restricted for specific standard.
   *
   * @param fnSig The function signature to check.
   * @param standard The standard to check.
   * @return yes True if the function is restricted for the specific standard.
   */
  function restricted(bytes4 fnSig, TokenStandard standard) public view returns (bool yes) {
    yes = _getFunctionalRestrictable()._enumBitmap[fnSig] & _toBitmap(standard) != 0;
  }

  /**
   * @dev Restrict a specific function with standard bitmap.
   */
  function _restrict(bytes4 fnSig, uint8 enumBitmap) internal {
    _getFunctionalRestrictable()._enumBitmap[fnSig] = enumBitmap;

    if (enumBitmap == 0) {
      emit UnRestricted(msg.sender, fnSig);
    } else {
      emit Restricted(msg.sender, fnSig, enumBitmap);
    }
  }

  /**
   * @dev Validate the caller is authorized.
   */
  function _requireAuth() internal virtual;

  /**
   * @dev Require the function with specific `msg.sig` is not restricted for the specific standard.
   */
  function _requireNotRestricted(
    TokenStandard standard
  ) internal view {
    require(!restricted(msg.sig, standard), ErrRestricted(msg.sig, standard));
  }

  /**
   * @dev Convert the TokenStandard to bitmap.
   */
  function _toBitmap(
    TokenStandard standard
  ) internal pure returns (uint8) {
    return uint8(1 << uint8(standard));
  }

  /**
   * @dev Returns the storage pointer of the FunctionalRestrictableStorage struct.
   */
  function _getFunctionalRestrictable() private pure returns (FunctionalRestrictableStorage storage $) {
    // value is equal to keccak256(abi.encode(uint256(keccak256("ronin.bridge.FunctionRestrictable")) - 1)) &
    // ~bytes32(uint256(0xff))
    bytes32 storageLoc = 0xa7959878b25ffc8190f7b5440888c97e9a819bbb4963604c213ae021e3145700;

    assembly ("memory-safe") {
      $.slot := storageLoc
    }
  }
}
