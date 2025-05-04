// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20MintBurn {
  function mint(address to, uint256 amount) external;

  function burn(
    uint256 amount
  ) external;

  function burnFrom(address account, uint256 amount) external;
}

contract LegacyTokenMigrator is Initializable, AccessControlEnumerable {
  using SafeERC20 for IERC20;

  mapping(address legacyToken => address newToken) internal _tokenMap;

  error MintTokenFailed(address token, uint256 amount);
  error NullAmount();
  error TokenNotMapped();
  error LengthMismatch();
  error DecimalsMismatch(uint8 legacyDecimals, uint8 newDecimals);

  event TokenMapped(address indexed by, address indexed legacyToken, address indexed newToken);
  event Converted(address indexed user, address indexed fromToken, address indexed toToken, uint256 amount);
  event LegacyTokenBurned(address indexed by, address indexed token, uint256 amount);
  event LegacyTokenLocked(address indexed by, address indexed token, uint256 amount);

  constructor() {
    _disableInitializers();
  }

  function initialize(address admin, address[] calldata legacyTokens, address[] calldata newTokens) external initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);

    require(legacyTokens.length == newTokens.length, LengthMismatch());

    for (uint256 i; i < legacyTokens.length; ++i) {
      _mapToken(legacyTokens[i], newTokens[i]);
    }
  }

  /**
   * @dev See {_mapToken}.
   */
  function mapToken(address legacyToken, address newToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _mapToken(legacyToken, newToken);
  }

  /**
   * @dev Converts a legacy token to a new token.
   *
   * Requirements:
   * - The amount must be non-zero.
   * - `msg.sender` must approve the contract to spend the legacy token.
   *
   * @param legacyToken Address of the legacy token.
   * @param amount Amount of the legacy token to convert.
   */
  function convert(address legacyToken, uint256 amount) external {
    address newToken = getTokenMap(legacyToken);

    require(amount != 0, NullAmount());
    require(newToken != address(0), TokenNotMapped());

    // Attempt to burn the legacy token, otherwise lock it in the contract
    try IERC20MintBurn(legacyToken).burnFrom(msg.sender, amount) {
      emit LegacyTokenBurned(msg.sender, legacyToken, amount);
    } catch {
      IERC20(legacyToken).safeTransferFrom(msg.sender, address(this), amount);
      emit LegacyTokenLocked(msg.sender, legacyToken, amount);
    }

    // Mint the new token if the contract balance is insufficient
    uint256 selfBalance = IERC20(newToken).balanceOf(address(this));
    if (selfBalance < amount) {
      try IERC20MintBurn(newToken).mint(address(this), amount - selfBalance) { }
      catch {
        revert MintTokenFailed(newToken, amount - selfBalance);
      }
    }

    // Transfer the new token to the user
    IERC20(newToken).safeTransfer(msg.sender, amount);

    emit Converted(msg.sender, legacyToken, newToken, amount);
  }

  /**
   * @dev Returns the new token address for a given legacy token.
   */
  function getTokenMap(
    address legacyToken
  ) public view returns (address) {
    return _tokenMap[legacyToken];
  }

  /**
   * @dev Maps a legacy token to a new token.
   *
   * Requirements:
   * - Caller must have the `DEFAULT_ADMIN_ROLE`.
   * - Decimals of the legacy token and the new token must match.
   *
   * @param legacyToken Address of the legacy token.
   * @param newToken Address of the new token.
   */
  function _mapToken(address legacyToken, address newToken) internal {
    _tokenMap[legacyToken] = newToken;

    uint8 legacyDecimals = IERC20Metadata(legacyToken).decimals();
    uint8 newDecimals = IERC20Metadata(newToken).decimals();
    require(legacyDecimals == newDecimals, DecimalsMismatch(legacyDecimals, newDecimals));

    emit TokenMapped(msg.sender, legacyToken, newToken);
  }
}
