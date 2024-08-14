// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IPauseEnforcer } from "script/interfaces/IPauseEnforcer.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainPauseEnforcerDeploy is Migration {
  function run() public virtual returns (IPauseEnforcer) {
    return IPauseEnforcer(_deployProxy(Contract.MainchainPauseEnforcer.key(), EMPTY_ARGS));
  }
}
