// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { RoninGatewayV3Deploy } from "./RoninGatewayV3Deploy.s.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract RoninBridgeManagerDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;

    args = abi.encode(
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
    );
  }

  function run() public virtual returns (RoninBridgeManager) {
    return RoninBridgeManager(_deployImmutable(Contract.RoninBridgeManager.key()));
  }
}
