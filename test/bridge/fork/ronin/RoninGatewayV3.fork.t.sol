// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninGatewayV3 } from "src/ronin/gateway/RoninGatewayV3.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract RoninGatewayV3ForkTest is Test {
  using LibProxy for *;

  RoninGatewayV3 public constant roninGateway = RoninGatewayV3(payable(0x0CF8fF40a508bdBc39fBe1Bb679dCBa64E65C7Df)); // Ronin Gateway V3 on Ronin Mainnet
  address proxyAdmin;

  function setUp() public {
    vm.createSelectFork("ronin-mainnet", 46124245); // hardcoded to the block where the upgrade was executed
    address logic = 0x838ac25e9998a3486Db5eB956F8B2fE894c1c6e0;
    proxyAdmin = address(roninGateway).getProxyAdmin();
    vm.prank(proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(roninGateway))).upgradeTo(logic);
  }

  function testForkConcrete_ValidTokenConfig() external view {
    assertEq(IERC20Metadata(address(roninGateway.APRS())).symbol(), "APRS");
    assertEq(IERC20Metadata(address(roninGateway.LUA())).symbol(), "LUA");
    assertEq(IERC20Metadata(address(roninGateway.LUAUSD())).symbol(), "LUAUSD");
    assertEq(IERC20Metadata(address(roninGateway.YGG())).symbol(), "YGG");
    assertEq(IERC20Metadata(address(roninGateway.WBTC())).symbol(), "WBTC");
    assertEq(IERC20Metadata(address(roninGateway.PIXEL())).symbol(), "PIXEL");
    assertEq(IERC20Metadata(address(roninGateway.USDC())).symbol(), "USDC");
    assertEq(IERC20Metadata(address(roninGateway.AXS())).symbol(), "AXS");
    assertEq(IERC20Metadata(address(roninGateway.SLP())).symbol(), "SLP");
    assertEq(IERC20Metadata(address(roninGateway.WETH())).symbol(), "WETH");
  }

  function testForkConcrete_burnAll() external {
    roninGateway.initializeV5();

    assertEq(roninGateway.APRS().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.LUA().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.LUAUSD().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.YGG().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.WBTC().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.PIXEL().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.USDC().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.AXS().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.SLP().balanceOf(address(roninGateway)), 0);
    assertEq(roninGateway.WETH().balanceOf(address(roninGateway)), 0);
  }
}
