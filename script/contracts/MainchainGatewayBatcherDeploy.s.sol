// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MainchainGatewayBatcher } from "@ronin/contracts/mainchain/MainchainGatewayBatcher.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainGatewayBatcherDeploy is Migration {
  function run() public virtual returns (MainchainGatewayBatcher) {
    return MainchainGatewayBatcher(_deployProxy(Contract.MainchainGatewayBatcher.key(), EMPTY_ARGS));
  }

  function runWithArgs(bytes memory args) public virtual returns (MainchainGatewayBatcher) {
    return MainchainGatewayBatcher(_deployProxy(Contract.MainchainGatewayBatcher.key(), args));
  }
}
