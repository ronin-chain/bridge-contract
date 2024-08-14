// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeSlash } from "@ronin/contracts/interfaces/bridge/IBridgeSlash.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract BridgeSlashDeploy is Migration {
  function run() public virtual returns (IBridgeSlash) {
    return IBridgeSlash(_deployProxy(Contract.BridgeSlash.key(), EMPTY_ARGS));
  }
}
