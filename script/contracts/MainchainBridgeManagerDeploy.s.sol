// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Contract } from "../utils/Contract.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainBridgeManagerDeploy is Migration {
  using LibProxy for *;

  function _getProxyAdmin() internal virtual override returns (address payable) {
    return payable(0xA62DddCC58E769bCFd2f9A7A61CDF331f18c2650);
  }

  function run() public virtual returns (IMainchainBridgeManager instance) {
    instance = IMainchainBridgeManager(_deployProxy(Contract.MainchainBridgeManager.key(), sender()));

    // if (proxyAdmin != address(instance)) {
    //   vm.broadcast(proxyAdmin);
    //   // change proxy admin to self
    //   TransparentUpgradeableProxy(payable(address(instance))).changeAdmin(address(instance));
    // }
  }
}
