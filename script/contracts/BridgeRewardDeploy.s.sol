// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { BridgeTrackingDeploy } from "./BridgeTrackingDeploy.s.sol";
import { RoninBridgeManagerDeploy } from "./RoninBridgeManagerDeploy.s.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract BridgeRewardDeploy is Migration {
  function run() public virtual returns (BridgeReward) {
    return BridgeReward(_deployProxy(Contract.BridgeReward.key(), EMPTY_ARGS));
  }
}
