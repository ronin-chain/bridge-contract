// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

import { MainchainGatewayV3Deploy } from "./MainchainGatewayV3Deploy.s.sol";

contract MainchainBridgeManagerDeploy is Migration {
  function run() public virtual returns (MainchainBridgeManager) {
    return MainchainBridgeManager(_deployProxy(Contract.MainchainBridgeManager.key()));
  }
}
