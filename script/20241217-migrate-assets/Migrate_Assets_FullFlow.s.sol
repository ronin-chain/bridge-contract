// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Migration } from "script/Migration.s.sol";

import { AssetMigration_PostChecker } from "script/20241217-migrate-assets/postcheck/AssetMigration_PostChecker.s.sol";
import { Migrate_Assets_Base } from "script/20241217-migrate-assets/Migrate_Assets_Base.s.sol";
import { Migration_01_Deploy_PauseEnforcer_And_Gateway } from "script/20241217-migrate-assets/01_Deploy_PauseEnforcer_And_Gateway.s.sol";
import { Migration_02_Propose_Upgrades } from "script/20241217-migrate-assets/02_Propose_Upgrades.s.sol";

contract Migrate_Assets_FullFlow is Migration {
  Migration_01_Deploy_PauseEnforcer_And_Gateway public migration_01;
  Migration_02_Propose_Upgrades public migration_02;

  function run() public virtual {
    migration_01 = new Migration_01_Deploy_PauseEnforcer_And_Gateway();
    migration_01.run();

    migration_02 = new Migration_02_Propose_Upgrades();
    migration_02.run();
  }

  function _postCheck() internal virtual override {
    migration_02.postCheck();
    AssetMigration_PostChecker assetMigration_PostChecker = new AssetMigration_PostChecker();
    assetMigration_PostChecker.run();

    // super._postCheck();
  }
}
