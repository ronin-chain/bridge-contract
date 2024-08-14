// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract BridgeRewardDeploy is Migration {
  function run() public virtual returns (IBridgeReward) {
    return IBridgeReward(_deployProxy(Contract.BridgeReward.key(), EMPTY_ARGS));
  }
}
