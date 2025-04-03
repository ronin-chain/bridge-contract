// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { RoninBridgeManagerConstructor } from "@ronin/contracts/ronin/gateway/RoninBridgeManagerConstructor.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninGatewayV3Deploy } from "./RoninGatewayV3Deploy.s.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";
import { LibDeploy, DeployInfo, ProxyInterface, UpgradeInfo } from "@fdk/libraries/LibDeploy.sol";

contract RoninBridgeManagerDeploy is Migration {
  using LibProxy for *;

  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;
    args = abi.encodeCall(
      RoninBridgeManagerConstructor.initialize,
      (
        param.num,
        param.denom,
        param.roninChainId,
        param.expiryDuration,
        param.bridgeContract,
        param.callbackRegisters,
        param.bridgeOperators,
        param.governors,
        param.voteWeights,
        param.targetOptions,
        param.targets
      )
    );
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    return sender();
  }

  function run() public virtual returns (IRoninBridgeManager) {
    address payable instance = _deployProxy(Contract.RoninBridgeManagerConstructor.key(), sender());
    address logic = _deployLogic(Contract.RoninBridgeManager.key());
    address proxyAdmin = instance.getProxyAdmin();
    console.log("Proxy admin ", proxyAdmin);
    console.log("Sender: ", sender());

    UpgradeInfo({
      proxy: instance,
      logic: logic,
      callValue: 0,
      callData: EMPTY_ARGS,
      proxyInterface: ProxyInterface.Transparent,
      shouldPrompt: false,
      upgradeCallback: _upgradeCallback,
      shouldUseCallback: true
    }).upgrade();

    // if (proxyAdmin != instance) {
    //   vm.broadcast(proxyAdmin);
    //   // change proxy admin to self
    //   TransparentUpgradeableProxy(instance).changeAdmin(instance);
    // }
    config.setAddress(network(), Contract.RoninBridgeManager.key(), instance);

    return IRoninBridgeManager(instance);
  }
}
