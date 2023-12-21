// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString, TContract } from "foundry-deployment-kit/types/Types.sol";

enum Contract {
  BridgeReward,
  BridgeSlash,
  BridgeTracking,
  RoninBridgeManager,
  RoninGatewayV3,
  MainchainBridgeManager,
  MainchainGatewayV3
}

using { key, name } for Contract global;

function key(Contract contractEnum) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(contractEnum)));
}

function name(Contract contractEnum) pure returns (string memory) {
  if (contractEnum == Contract.BridgeReward) return "BridgeReward";
  if (contractEnum == Contract.BridgeSlash) return "BridgeSlash";
  if (contractEnum == Contract.BridgeTracking) return "BridgeTracking";
  if (contractEnum == Contract.RoninBridgeManager) return "RoninBridgeManager";
  if (contractEnum == Contract.RoninGatewayV3) return "RoninGatewayV3";
  if (contractEnum == Contract.MainchainBridgeManager) return "MainchainBridgeManager";
  if (contractEnum == Contract.MainchainGatewayV3) return "MainchainGatewayV3";
  revert("Contract: Unknown contract");
}
