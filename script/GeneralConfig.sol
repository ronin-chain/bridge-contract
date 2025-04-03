// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console } from "forge-std/console.sol";
import { BaseGeneralConfig } from "@fdk/BaseGeneralConfig.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Contract } from "./utils/Contract.sol";
import { TNetwork, Network } from "./utils/Network.sol";
import { IGeneralConfigExtended } from "./interfaces/IGeneralConfigExtended.sol";
import { Utils } from "./utils/Utils.sol";

contract GeneralConfig is BaseGeneralConfig, Utils {
  IGeneralConfigExtended.LocalNetwork private _localNetwork;

  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(Network.Sepolia.data());
    setNetworkInfo(Network.EthMainnet.data());
    setNetworkInfo(Network.RoninDevnet.data());
  }

  function getCompanionNetwork(
    TNetwork network
  ) public view virtual returns (TNetwork companionNetwork) {
    if (network == DefaultNetwork.RoninMainnet.key()) return Network.EthMainnet.key();
    if (network == Network.EthMainnet.key()) return DefaultNetwork.RoninMainnet.key();
    if (network == DefaultNetwork.RoninTestnet.key()) return Network.Sepolia.key();
    if (network == Network.Sepolia.key()) return DefaultNetwork.RoninTestnet.key();
    if (network == DefaultNetwork.LocalHost.key()) return DefaultNetwork.LocalHost.key();

    revert("Network: Unknown companion network");
  }

  function getLocalNetwork() public view virtual returns (IGeneralConfigExtended.LocalNetwork) {
    return _localNetwork;
  }

  function setLocalNetwork(
    IGeneralConfigExtended.LocalNetwork network
  ) public virtual {
    _localNetwork = network;
  }

  function _setUpContracts() internal virtual override {
    setContractAbsolutePathMap(Contract.PostChecker.key(), "out/PostChecker.sol/PostChecker.json");

    // map contract name
    _mapContractName(Contract.BridgeSlash);
    _mapContractName(Contract.MockERC721);
    _mapContractName(Contract.BridgeReward);
    _mapContractName(Contract.BridgeTracking);
    _mapContractName(Contract.RoninGatewayV3);
    _mapContractName(Contract.RoninBridgeManager);
    _mapContractName(Contract.MainchainGatewayV3);
    _mapContractName(Contract.MainchainGatewayBatcher);
    _mapContractName(Contract.MainchainBridgeManager);
    _mapContractName(Contract.MockERC721);
    _mapContractName(Contract.MockERC1155);
    _mapContractName(Contract.RoninBridgeManagerConstructor);
    _mapContractName(Contract.WBTC);
    _mapContractName(Contract.PostChecker);
    _mapContractName(Contract.WETH);

    _contractNameMap[Contract.AXS.key()] = "MockERC20";
    _contractNameMap[Contract.SLP.key()] = "MockSLP";
    _contractNameMap[Contract.USDC.key()] = "MockUSDC";
    _contractNameMap[Contract.WRON.key()] = "MockWrappedToken";
    _contractNameMap[Contract.WETH.key()] = "MockWrappedToken";
    _contractNameMap[Contract.MainchainWethUnwrapper.key()] = "WethUnwrapper";

    _contractNameMap[Contract.RoninPauseEnforcer.key()] = "PauseEnforcer";
    _contractNameMap[Contract.MainchainPauseEnforcer.key()] = "PauseEnforcer";

    _contractAddrMap[Network.Goerli.key()][Contract.WETH.name()] = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    _contractAddrMap[Network.EthMainnet.key()][Contract.WETH.name()] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    _contractAddrMap[DefaultNetwork.RoninTestnet.key()][Contract.AXS.name()] = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;

    _contractAddrMap[DefaultNetwork.RoninMainnet.key()][Contract.WETH.name()] = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;
    _contractAddrMap[DefaultNetwork.RoninMainnet.key()][Contract.WRON.name()] = 0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4;

    _contractAddrMap[DefaultNetwork.RoninTestnet.key()][Contract.WETH.name()] = 0x29C6F8349A028E1bdfC68BFa08BDee7bC5D47E16;
    _contractAddrMap[DefaultNetwork.RoninTestnet.key()][Contract.WRON.name()] = 0xA959726154953bAe111746E265E6d754F48570E6;

    TNetwork currNetwork = getCurrentNetwork();
    if (currNetwork == Network.Sepolia.key()) _contractNameMap[Contract.WBTC.key()] = "WBTC_Sepolia";
    if (currNetwork == DefaultNetwork.LocalHost.key()) _contractNameMap[Contract.MainchainGatewayV3.key()] = "MainchainGatewayV3_initialize";
    if (currNetwork == DefaultNetwork.LocalHost.key()) _contractNameMap[Contract.RoninGatewayV3.key()] = "RoninGatewayV3_initialize";
  }

  function _mapContractName(
    Contract contractEnum
  ) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    bool isLocalNetwork = getCurrentNetwork() == DefaultNetwork.LocalHost.key();

    if (sender == address(0x0) && isLocalNetwork) sender = payable(DEFAULT_SENDER);
    require(sender != address(0x0), "GeneralConfig: Sender is address(0x0)");
  }
}
