// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SideChainGatewayBurner {
  address private immutable i_admin;
  ERC20Burnable public constant USDC = ERC20Burnable(0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc); // USDC on Ronin Mainnet
  ERC20Burnable public constant AXS = ERC20Burnable(0x97a9107C1793BC407d6F527b77e7fff4D812bece); // AXS on Ronin Mainnet
  ERC20Burnable public constant SLP = ERC20Burnable(0xa8754b9Fa15fc18BB59458815510E40a12cD2014); // SLP on Ronin Mainnet
  IERC20 public constant WETH = IERC20(0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5); // WETH on Ronin Mainnet

  function getAdmin() external view returns (address) {
    return i_admin;
  }

  constructor(
    address admin
  ) {
    require(admin != address(0), "Admin cannot be zero address");
    require(block.chainid == 2020, "Wrong chain ID, must be Ronin Mainnet");

    i_admin = admin;
  }

  function burnAll() external {
    require(msg.sender == i_admin, "Only admin can burn");

    USDC.burn(USDC.balanceOf(address(this)));
    AXS.burn(AXS.balanceOf(address(this)));
    SLP.burn(SLP.balanceOf(address(this)));
    // WETH cannot be burned, then it must be transferred to 0xdead
    require(WETH.transfer(address(0xdead), WETH.balanceOf(address(this))), "Transfer of WETH to 0xdead failed");
  }
}
