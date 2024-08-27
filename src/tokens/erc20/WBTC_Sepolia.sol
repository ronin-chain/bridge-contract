// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WBTC_Sepolia is ERC20 {
  /**
   * @inheritdoc ERC20
   */
  function decimals() public view virtual override returns (uint8) {
    return 8;
  }

  constructor() ERC20("Wrapped Bitcoin", "WBTC") {
    _mint(msg.sender, 500_000 ether);
  }
}
