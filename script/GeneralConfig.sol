// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 as console } from "forge-std/console2.sol";
import { BaseGeneralConfig } from "foundry-deployment-kit/BaseGeneralConfig.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { Contract } from "./utils/Contract.sol";
import { Network } from "./utils/Network.sol";
import { Utils } from "./utils/Utils.sol";

contract GeneralConfig is BaseGeneralConfig, Utils {
  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(
      Network.Goerli.chainId(),
      Network.Goerli.key(),
      Network.Goerli.chainAlias(),
      Network.Goerli.deploymentDir(),
      Network.Goerli.envLabel(),
      Network.Goerli.explorer()
    );
    setNetworkInfo(
      Network.EthMainnet.chainId(),
      Network.EthMainnet.key(),
      Network.EthMainnet.chainAlias(),
      Network.EthMainnet.deploymentDir(),
      Network.EthMainnet.envLabel(),
      Network.EthMainnet.explorer()
    );
    setNetworkInfo(
      Network.RoninDevnet.chainId(),
      Network.RoninDevnet.key(),
      Network.RoninDevnet.chainAlias(),
      Network.RoninDevnet.deploymentDir(),
      Network.RoninDevnet.envLabel(),
      Network.RoninDevnet.explorer()
    );
  }

  function _setUpContracts() internal virtual override {
    // map contract name
    _mapContractName(Contract.BridgeTracking);
    _mapContractName(Contract.BridgeSlash);
    _mapContractName(Contract.BridgeReward);
    _mapContractName(Contract.RoninGatewayV3);
    _mapContractName(Contract.RoninBridgeManager);
    _mapContractName(Contract.MainchainGatewayV3);
    _mapContractName(Contract.MainchainBridgeManager);

    _contractNameMap[Contract.WETH.key()] = "MockWrappedToken";
    _contractNameMap[Contract.WRON.key()] = "MockWrappedToken";
    _contractNameMap[Contract.AXS.key()] = "MockERC20";
    _contractNameMap[Contract.SLP.key()] = "MockERC20";
    _contractNameMap[Contract.USDC.key()] = "MockERC20";

    if (getCurrentNetwork() == DefaultNetwork.Local.key()) {
      address deployer = getSender();

      // ronin bridge contracts
      setAddress(DefaultNetwork.Local.key(), Contract.RoninGatewayV3.key(), vm.computeCreateAddress(deployer, 4));
      setAddress(DefaultNetwork.Local.key(), Contract.BridgeTracking.key(), vm.computeCreateAddress(deployer, 6));
      setAddress(DefaultNetwork.Local.key(), Contract.BridgeSlash.key(), vm.computeCreateAddress(deployer, 8));
      setAddress(DefaultNetwork.Local.key(), Contract.BridgeReward.key(), vm.computeCreateAddress(deployer, 10));
      setAddress(DefaultNetwork.Local.key(), Contract.RoninBridgeManager.key(), vm.computeCreateAddress(deployer, 11));

      //mainchain bridge contracts
      setAddress(DefaultNetwork.Local.key(), Contract.MainchainGatewayV3.key(), vm.computeCreateAddress(deployer, 13));
      setAddress(
        DefaultNetwork.Local.key(), Contract.MainchainBridgeManager.key(), vm.computeCreateAddress(deployer, 14)
      );

      // ronin tokens
      setAddress(DefaultNetwork.Local.key(), Contract.WETH.key(), vm.computeCreateAddress(deployer, 15));
      setAddress(DefaultNetwork.Local.key(), Contract.AXS.key(), vm.computeCreateAddress(deployer, 16));
      setAddress(DefaultNetwork.Local.key(), Contract.SLP.key(), vm.computeCreateAddress(deployer, 17));
      setAddress(DefaultNetwork.Local.key(), Contract.USDC.key(), vm.computeCreateAddress(deployer, 18));
    }
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
