// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WBTC, WBTCDeploy } from "script/contracts/WBTCDeploy.s.sol";
import { LegacyTokenMigrator, LegacyTokenMigratorDeploy } from "script/contracts/LegacyTokenMigratorDeploy.s.sol";
import { Migration } from "script/Migration.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__20252101_DeployWBTCAndLegacyMigrator is Migration {
  function run() public virtual {
    address prvWBTC = loadContract(Contract.WBTC.key());

    WBTC newBTC = new WBTCDeploy().run();
    LegacyTokenMigrator migrator = new LegacyTokenMigratorDeploy().run();

    address admin = 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a; // Multisig Address
    address[] memory legacyTokens = new address[](1);
    legacyTokens[0] = prvWBTC;
    address[] memory newTokens = new address[](1);
    newTokens[0] = address(newBTC);

    vm.broadcast(sender());
    migrator.initialize(admin, legacyTokens, newTokens);
  }
}
