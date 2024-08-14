// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract BridgeTrackingDeploy is Migration {
  function run() public virtual returns (IBridgeTracking) {
    return IBridgeTracking(_deployProxy(Contract.BridgeTracking.key(), EMPTY_ARGS));
  }
}
