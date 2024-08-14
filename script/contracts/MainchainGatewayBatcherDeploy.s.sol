// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMainchainGatewayBatcher } from "script/interfaces/IMainchainGatewayBatcher.sol";

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainGatewayBatcherDeploy is Migration {
  function run() public virtual returns (IMainchainGatewayBatcher) {
    return IMainchainGatewayBatcher(_deployProxy(Contract.MainchainGatewayBatcher.key(), EMPTY_ARGS));
  }

  function runWithArgs(bytes memory args) public virtual returns (IMainchainGatewayBatcher) {
    return IMainchainGatewayBatcher(_deployProxy(Contract.MainchainGatewayBatcher.key(), args));
  }
}
