// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PauseEnforcer } from "@ronin/contracts/ronin/gateway/PauseEnforcer.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainPauseEnforcerDeploy is Migration {
  function run() public virtual returns (PauseEnforcer) {
    return PauseEnforcer(_deployProxy(Contract.MainchainPauseEnforcer.key(), EMPTY_ARGS));
  }
}
