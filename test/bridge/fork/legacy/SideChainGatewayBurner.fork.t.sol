// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { SideChainGatewayBurner } from "src/legacy/SideChainGatewayBurner.sol";

interface IProxy {
  function admin() external view returns (address);

  function updateProxyTo(
    address newImplementation
  ) external;
}

contract SideChainGatewayBurnerForkTest is Test {
  SideChainGatewayBurner burner;

  address internal _admin = makeAddr("admin");
  address internal _proxyAdmin;
  address internal constant SIDE_CHAIN_GATEWAY = 0xe35d62Ebe18413d96CA2A2f7cF215bB21a406b4B;

  function setUp() public {
    vm.createSelectFork("ronin-mainnet"); // Replace with a valid block number
    _proxyAdmin = IProxy(SIDE_CHAIN_GATEWAY).admin();

    burner = new SideChainGatewayBurner(_proxyAdmin);

    vm.prank(_proxyAdmin);
    IProxy(SIDE_CHAIN_GATEWAY).updateProxyTo(address(burner));
  }

  function testForkConcrete_BurnAll() external {
    vm.prank(_proxyAdmin);
    SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).burnAll();

    assertEq(SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).USDC().balanceOf(SIDE_CHAIN_GATEWAY), 0, "USDC balance should be zero after burn");
    assertEq(SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).AXS().balanceOf(SIDE_CHAIN_GATEWAY), 0, "AXS balance should be zero after burn");
    assertEq(SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).SLP().balanceOf(SIDE_CHAIN_GATEWAY), 0, "SLP balance should be zero after burn");
    assertEq(SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).WETH().balanceOf(SIDE_CHAIN_GATEWAY), 0, "WETH balance should be zero after transfer to 0xdead");
    assertEq(SideChainGatewayBurner(SIDE_CHAIN_GATEWAY).getAdmin(), _proxyAdmin, "Admin should be set correctly");
  }
}
