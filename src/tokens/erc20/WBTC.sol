// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract WBTC is Initializable, ERC20PresetMinterPauser {
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

  constructor() ERC20PresetMinterPauser("", "") {
    _revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _revokeRole(MINTER_ROLE, _msgSender());
    _revokeRole(PAUSER_ROLE, _msgSender());

    _disableInitializers();
  }

  function initialize(address admin, address minter, address burner, address pauser) external initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(PAUSER_ROLE, pauser);
    _grantRole(BURNER_ROLE, burner);
    _grantRole(MINTER_ROLE, minter);
  }

  /**
   * @inheritdoc ERC20
   */
  function name() public view virtual override returns (string memory) {
    return "Wrapped Bitcoin";
  }

  /**
   * @inheritdoc ERC20
   */
  function symbol() public view virtual override returns (string memory) {
    return "WBTC";
  }

  /**
   * @inheritdoc ERC20
   */
  function decimals() public view virtual override returns (uint8) {
    return 8;
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20PresetMinterPauser) {
    if (to == address(0)) {
      require(hasRole(BURNER_ROLE, _msgSender()), "WBTC: only burner can burn tokens");
    }

    super._beforeTokenTransfer(from, to, amount);
  }
}
