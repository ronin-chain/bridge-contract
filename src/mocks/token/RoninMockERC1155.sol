// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RoninMockERC1155 is ERC1155Burnable, AccessControl {
  // Token name
  string internal _name;
  // Token symbol
  string internal _symbol;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

  constructor(address defaultAdmin, string memory uri, string memory name, string memory symbol) ERC1155(uri) {
    _name = name;
    _symbol = symbol;
    _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
  }

  function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyRole(MINTER_ROLE) {
    _mint(account, id, amount, data);
  }

  function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyRole(MINTER_ROLE) {
    _mintBatch(to, ids, amounts, data);
  }

  function burn(address from, uint256 id, uint256 value) public override onlyRole(BURNER_ROLE) {
    _burn(from, id, value);
  }

  function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) public override onlyRole(BURNER_ROLE) {
    _burnBatch(from, ids, amounts);
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
    return ERC1155.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}
