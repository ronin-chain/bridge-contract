// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

abstract contract BasePostCheck is BaseMigration {
  using StdStyle for *;

  uint256 internal seed = vm.unixTime();
  address internal __bridgeSlash;
  address internal __bridgeReward;
  address internal __bridgeTracking;
  mapping(uint256 chainId => address manager) internal _manager;
  mapping(uint256 chainId => address gateway) internal _gateway;

  modifier onPostCheck(string memory postCheckLabel) {
    uint256 snapshotId = _beforePostCheck(postCheckLabel);
    _;
    _afterPostCheck(postCheckLabel, snapshotId);
  }

  function _beforePostCheck(string memory postCheckLabel) private returns (uint256 snapshotId) {
    snapshotId = vm.snapshot();
    console.log("\n> ".cyan(), postCheckLabel.blue().italic(), "...");
  }

  function _afterPostCheck(string memory postCheckLabel, uint256 snapshotId) private {
    console.log(string.concat("Postcheck ", postCheckLabel.italic(), " successful!\n").green());
    vm.revertTo(snapshotId);
  }
}
