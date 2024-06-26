// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { RoninGatewayV3Deploy } from "./RoninGatewayV3Deploy.s.sol";

contract BridgeTrackingDeploy is Migration {
  function run() public virtual returns (BridgeTracking) {
    return BridgeTracking(_deployProxy(Contract.BridgeTracking.key(), EMPTY_ARGS));
  }
}
