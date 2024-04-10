// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 as console } from "forge-std/console2.sol";
import { BaseGeneralConfig } from "foundry-deployment-kit/BaseGeneralConfig.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { TNetwork } from "foundry-deployment-kit/types/Types.sol";
import { Contract } from "./utils/Contract.sol";
import { Network } from "./utils/Network.sol";
import { Utils } from "./utils/Utils.sol";

contract GeneralConfig is BaseGeneralConfig, Utils {
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
    _mapContractName(Contract.MockERC721);
    _mapContractName(Contract.RoninBridgeManagerConstructor);

    _contractNameMap[Contract.WETH.key()] = "MockWrappedToken";
    _contractNameMap[Contract.WRON.key()] = "MockWrappedToken";
    _contractNameMap[Contract.AXS.key()] = "MockERC20";
    _contractNameMap[Contract.SLP.key()] = "MockSLP";
    _contractNameMap[Contract.USDC.key()] = "MockUSDC";

    _contractNameMap[Contract.RoninPauseEnforcer.key()] = "PauseEnforcer";
    _contractNameMap[Contract.MainchainPauseEnforcer.key()] = "PauseEnforcer";

    _contractNameMap[Contract.MainchainWethUnwrapper.key()] = "WethUnwrapper";
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }

  function getSender() public view virtual override returns (address payable sender) {
    sender = _option.trezor ? payable(_trezorSender) : payable(_envSender);
    bool isLocalNetwork = getCurrentNetwork() == DefaultNetwork.Local.key();

    if (sender == address(0x0) && isLocalNetwork) sender = payable(DEFAULT_SENDER);
    require(sender != address(0x0), "GeneralConfig: Sender is address(0x0)");
  }

  function getCompanionNetwork(TNetwork network) external pure returns (Network) {
    if (network == DefaultNetwork.RoninTestnet.key()) return Network.Sepolia;
    if (network == DefaultNetwork.RoninMainnet.key()) return Network.EthMainnet;
    revert("Network: Unknown companion network");
  }
}
