// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Contract } from "../utils/Contract.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { MainchainGatewayV3Deploy } from "./MainchainGatewayV3Deploy.s.sol";

contract MainchainBridgeManagerDeploy is Migration {
  using LibProxy for *;

  function run() public virtual returns (MainchainBridgeManager instance) {
    instance = MainchainBridgeManager(_deployProxy(Contract.MainchainBridgeManager.key(), sender()));
    address proxyAdmin = payable(address(instance)).getProxyAdmin();

    if (proxyAdmin == sender()) {
      vm.broadcast(proxyAdmin);
      // change proxy admin to self
      TransparentUpgradeableProxy(payable(address(instance))).changeAdmin(address(instance));
    }
  }
}
