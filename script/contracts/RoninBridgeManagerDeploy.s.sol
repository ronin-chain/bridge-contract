// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { RoninBridgeManagerConstructor } from "@ronin/contracts/ronin/gateway/RoninBridgeManagerConstructor.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninGatewayV3Deploy } from "./RoninGatewayV3Deploy.s.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

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

  function run() public virtual returns (RoninBridgeManager) {
    address payable instance = _deployProxy(Contract.RoninBridgeManagerConstructor.key(), sender());
    address logic = _deployLogic(Contract.RoninBridgeManager.key());
    address proxyAdmin = instance.getProxyAdmin();
    console2.log("Proxy admin ", proxyAdmin);
    console2.log("Sender: ", sender());
    _upgradeRaw(proxyAdmin, instance, logic, EMPTY_ARGS);

    if (proxyAdmin == sender()) {
      vm.broadcast(proxyAdmin);
      // change proxy admin to self
      TransparentUpgradeableProxy(instance).changeAdmin(instance);
    }
    config.setAddress(network(), Contract.RoninBridgeManager.key(), instance);

    return RoninBridgeManager(instance);
  }
}
