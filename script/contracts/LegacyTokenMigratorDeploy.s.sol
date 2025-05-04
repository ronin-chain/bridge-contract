// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LegacyTokenMigrator } from "src/ronin/migration/LegacyTokenMigrator.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";

contract LegacyTokenMigratorDeploy is Migration {
  function run() public virtual returns (LegacyTokenMigrator instance) {
    instance = LegacyTokenMigrator(_deployProxy(Contract.LegacyTokenMigrator.key()));
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    // ronin-mainnet: SC Multisig
    return payable(0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a);
  }
}
