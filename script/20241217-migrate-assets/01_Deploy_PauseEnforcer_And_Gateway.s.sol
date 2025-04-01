// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import { PauseEnforcer } from "src/ronin/gateway/PauseEnforcer.sol";
import { IPauseTarget } from "src/interfaces/IPauseTarget.sol";

import { Migrate_Assets_Base } from "script/20241217-migrate-assets/Migrate_Assets_Base.s.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

import { TNetwork } from "@fdk/types/TNetwork.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

contract Migration_01_Deploy_PauseEnforcer_And_Gateway is Migrate_Assets_Base {
  using LibCompanionNetwork for *;

  address private _ronPauseEnforcer;
  address private _ronGatewayV3Logic;

  address private _ethPauseEnforcer;
  address private _ethGatewayV3Logic;

  function run() public virtual override {
    super.run();

    MigrateConfig memory ronCfg = ronConfig();
    MigrateConfig memory ethCfg = ethConfig();

    require(ronCfg.prevPauseEnforcer != address(0), "[Ronin] prevPauseEnforcer is required");
    require(ronCfg.newPauseEnforcer == address(0), "[Ronin] newPauseEnforcer must be empty");
    require(ronCfg.newGatewayLogic == address(0), "[Ronin] newGatewayLogic must be empty");

    require(ethCfg.prevPauseEnforcer != address(0), "[Ethereum] prevPauseEnforcer is required");
    require(ethCfg.newPauseEnforcer == address(0), "[Ethereum] newPauseEnforcer must be empty");
    require(ethCfg.newGatewayLogic == address(0), "[Ethereum] newGatewayLogic must be empty");

    address ronGw = loadContract(Contract.RoninGatewayV3.key());
    (address[] memory admins, address[] memory sentries) = _getAllSentriesFromPreviousPauseEnforcer(ronCfg.prevPauseEnforcer);

    _ronPauseEnforcer = _deployImmutable(Contract.RoninPauseEnforcer.key(), abi.encode(ronGw, admins, sentries));
    _ronGatewayV3Logic = _deployLogic(Contract.RoninGatewayV3.key());

    (, TNetwork companionNetwork) = network().companionNetworkData();

    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(companionNetwork);

    address ethGw = loadContract(Contract.MainchainGatewayV3.key());
    (admins, sentries) = _getAllSentriesFromPreviousPauseEnforcer(ethCfg.prevPauseEnforcer);

    _ethPauseEnforcer = _deployImmutable(Contract.MainchainPauseEnforcer.key(), abi.encode(ethGw, admins, sentries));
    _ethGatewayV3Logic = _deployLogic(Contract.MainchainGatewayV3.key());

    switchBack(prvNetwork, prvForkId);

    _saveToConfig();
  }

  function _saveToConfig() internal {
    string memory path = configPath();

    require(_ronPauseEnforcer != address(0), "Ronin Pause Enforcer is not deployed");
    require(_ronGatewayV3Logic != address(0), "Ronin Gateway Logic is not deployed");

    require(_ethPauseEnforcer != address(0), "Ethereum Pause Enforcer is not deployed");
    require(_ethGatewayV3Logic != address(0), "Ethereum Gateway Logic is not deployed");

    vm.writeJson(vm.toString(_ronPauseEnforcer), path, ".ronin.newPauseEnforcer");
    vm.writeJson(vm.toString(_ronGatewayV3Logic), path, ".ronin.newGatewayLogic");

    vm.writeJson(vm.toString(_ethPauseEnforcer), path, ".ethereum.newPauseEnforcer");
    vm.writeJson(vm.toString(_ethGatewayV3Logic), path, ".ethereum.newGatewayLogic");
  }

  function _getAllSentriesFromPreviousPauseEnforcer(
    address pauseEnforcer
  ) internal view returns (address[] memory admins, address[] memory sentries) {
    admins = new address[](AccessControlEnumerable(pauseEnforcer).getRoleMemberCount(0));
    sentries = new address[](AccessControlEnumerable(pauseEnforcer).getRoleMemberCount(keccak256("SENTRY_ROLE")));

    for (uint256 i; i < admins.length; ++i) {
      admins[i] = AccessControlEnumerable(pauseEnforcer).getRoleMember(0, i);
    }

    for (uint256 i; i < sentries.length; ++i) {
      sentries[i] = AccessControlEnumerable(pauseEnforcer).getRoleMember(keccak256("SENTRY_ROLE"), i);
    }
  }

  function _postCheck() internal virtual override { }
}
