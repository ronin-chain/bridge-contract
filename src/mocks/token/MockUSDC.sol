// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  /**
   * @dev USDC always have decimal is 6
   */
  function decimals() public pure override returns (uint8) {
    return 6;
  }
}
