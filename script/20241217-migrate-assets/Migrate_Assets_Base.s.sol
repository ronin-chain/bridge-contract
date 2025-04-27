// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Migration } from "script/Migration.s.sol";
import { Network } from "script/utils/Network.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

abstract contract Migrate_Assets_Base is Migration {
  struct WhitelistInfo {
    address recipient;
    uint64 remoteChainSelector;
    address token;
  }

  struct MigrateConfig {
    address executor;
    address migrator;
    address newGatewayLogic;
    address newPauseEnforcer;
    address prevPauseEnforcer;
    address proposer;
    WhitelistInfo[] whitelistInfos;
  }

  string private constant CONFIG_PATH = "script/20241217-migrate-assets/config/config";

  function run() public virtual {
    vm.makePersistent(address(this));
    validateConfig(ronConfig());
    validateConfig(ethConfig());
  }

  function configPath() public view returns (string memory) {
    if (network() == DefaultNetwork.RoninMainnet.key() || network() == Network.EthMainnet.key()) {
      return string.concat(CONFIG_PATH, ".mainnet.json");
    } else if (network() == DefaultNetwork.RoninTestnet.key() || network() == Network.Sepolia.key()) {
      return string.concat(CONFIG_PATH, ".testnet.json");
    } else {
      revert("Unsupported network");
    }
  }

  function validateConfig(
    MigrateConfig memory cfg
  ) public pure {
    require(cfg.executor != address(0), "executor is required");
    require(cfg.migrator != address(0), "migrator is required");
    require(cfg.proposer != address(0), "proposer is required");
    require(cfg.whitelistInfos.length > 0, "whitelistInfos is required");
  }

  function ronConfig() public view returns (MigrateConfig memory) {
    return this.parseConfig(vm.readFile(configPath()), ".ronin");
  }

  function ethConfig() public view returns (MigrateConfig memory) {
    return this.parseConfig(vm.readFile(configPath()), ".ethereum");
  }

  function parseConfig(string memory json, string memory key) external pure returns (MigrateConfig memory) {
    MigrateConfig memory parsed = abi.decode(vm.parseJson(json, key), (MigrateConfig));
    return parsed;
  }

  function toWhitelistData(
    WhitelistInfo[] memory info
  ) public pure returns (address[] memory tokens, address[] memory recipients, uint64[] memory remoteChainSelectors) {
    tokens = new address[](info.length);
    recipients = new address[](info.length);
    remoteChainSelectors = new uint64[](info.length);

    for (uint256 i; i < info.length; ++i) {
      tokens[i] = info[i].token;
      recipients[i] = info[i].recipient;
      remoteChainSelectors[i] = info[i].remoteChainSelector;
    }
  }
}
