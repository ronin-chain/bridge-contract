// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TNetwork } from "@fdk/types/Types.sol";
import { LibString } from "solady/utils/LibString.sol";
import { INetworkConfig } from "@fdk/interfaces/configs/INetworkConfig.sol";

enum Network {
  Goerli,
  Sepolia,
  EthMainnet,
  RoninDevnet
}

using { key, chainId, chainAlias, explorer, data } for Network global;

function data(Network network) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(network),
    chainAlias: chainAlias(network),
    blockTime: blockTime(network),
    explorer: explorer(network),
    chainId: chainId(network)
  });
}

function chainId(Network network) pure returns (uint256) {
  if (network == Network.Goerli) return 5;
  if (network == Network.Sepolia) return 11155111;
  if (network == Network.EthMainnet) return 1;
  if (network == Network.RoninDevnet) return 2022;

  revert("Network: Unknown chain id");
}

function key(Network network) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(network)));
}

function blockTime(Network network) pure returns (uint256) {
  if (network == Network.Goerli) return 15;
  if (network == Network.Sepolia) return 15;
  if (network == Network.EthMainnet) return 3;

  return type(uint256).max;
}

function explorer(Network network) pure returns (string memory link) {
  if (network == Network.Goerli) return "https://goerli.etherscan.io/";
  if (network == Network.Sepolia) return "https://sepolia.etherscan.io/";
  if (network == Network.EthMainnet) return "https://etherscan.io/";
}

function name(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "Goerli";
  if (network == Network.Sepolia) return "Sepolia";
  if (network == Network.RoninDevnet) return "RoninDevnet";
  if (network == Network.EthMainnet) return "EthMainnet";

  revert("Network: Unknown network name");
}

function deploymentDir(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "goerli/";
  if (network == Network.Sepolia) return "sepolia/";
  if (network == Network.EthMainnet) return "ethereum/";
  if (network == Network.RoninDevnet) return "ronin-devnet/";

  revert("Network: Unknown network deployment directory");
}

function envLabel(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "GOERLI_PK";
  if (network == Network.Sepolia) return "SEPOLIA_PK";
  if (network == Network.RoninDevnet) return "DEVNET_PK";
  if (network == Network.EthMainnet) return "MAINNET_PK";

  revert("Network: Unknown private key env label");
}

function chainAlias(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "goerli";
  if (network == Network.Sepolia) return "sepolia";
  if (network == Network.EthMainnet) return "ethereum";
  if (network == Network.RoninDevnet) return "ronin-devnet";

  revert("Network: Unknown network alias");
}
