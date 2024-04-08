// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninBridgeManagerConstructor } from "@ronin/contracts/ronin/gateway/RoninBridgeManagerConstructor.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
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
    address payable instance = _deployProxy(Contract.RoninBridgeManagerConstructor.key());
    address logic = _deployLogic(Contract.RoninBridgeManager.key());
    address proxyAdmin = instance.getProxyAdmin();
    _upgradeRaw(proxyAdmin, instance, logic, EMPTY_ARGS);
    return RoninBridgeManager(instance);
  }
}
