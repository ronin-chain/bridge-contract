// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSLP is ERC20 {
  constructor() ERC20("Smooth Love Potion", "SLP") { }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  /**
   * @dev SLP always have decimal is 0
   */
  function decimals() public pure override returns (uint8) {
    return 0;
  }
}
