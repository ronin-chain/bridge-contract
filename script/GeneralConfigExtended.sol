// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { BaseGeneralConfig } from "foundry-deployment-kit/BaseGeneralConfig.sol";
import { TNetwork } from "foundry-deployment-kit/types/Types.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { Network } from "./utils/Network.sol";
import { Contract } from "./utils/Contract.sol";

contract GeneralConfigExtended is BaseGeneralConfig {
  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(
      Network.Sepolia.chainId(),
      Network.Sepolia.key(),
      Network.Sepolia.chainAlias(),
      Network.Sepolia.deploymentDir(),
      Network.Sepolia.envLabel(),
      Network.Sepolia.explorer()
    );
    setNetworkInfo(
      Network.EthMainnet.chainId(),
      Network.EthMainnet.key(),
      Network.EthMainnet.chainAlias(),
      Network.EthMainnet.deploymentDir(),
      Network.EthMainnet.envLabel(),
      Network.EthMainnet.explorer()
    );
  }

  function _setUpContracts() internal virtual override {
    _mapContractname(Contract.BridgeReward);
    _mapContractname(Contract.BridgeSlash);
    _mapContractname(Contract.BridgeTracking);
    _mapContractname(Contract.RoninBridgeManager);
    _mapContractname(Contract.RoninGatewayV3);
    _mapContractname(Contract.MainchainBridgeManager);
    _mapContractname(Contract.MainchainGatewayV3);
  }

  function _mapContractname(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }

  function getCompanionNetwork(TNetwork network) external pure returns (Network) {
    if (network == DefaultNetwork.RoninTestnet.key()) return Network.Sepolia;
    if (network == DefaultNetwork.RoninMainnet.key()) return Network.EthMainnet;
    revert("Network: Unknown companion network");
  }
}
