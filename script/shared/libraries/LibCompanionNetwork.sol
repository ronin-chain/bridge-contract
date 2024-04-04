// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { IGeneralConfigExtended } from "script/interfaces/IGeneralConfigExtended.sol";
import { TNetwork } from "@fdk/types/Types.sol";

library LibCompanionNetwork {
  IGeneralConfigExtended private constant config = IGeneralConfigExtended(LibSharedAddress.CONFIG);

  function companionChainId() internal returns (uint256 chainId) {
    (chainId,) = companionNetworkData();
  }

  function companionChainId(TNetwork network) internal returns (uint256 chainId) {
    (chainId,) = companionNetworkData(network);
  }

  function companionNetwork() internal returns (TNetwork network) {
    (, network) = companionNetworkData();
  }

  function companionNetwork(TNetwork network) internal returns (TNetwork companionTNetwork) {
    (, companionTNetwork) = companionNetworkData(network);
  }

  function companionNetworkData() internal returns (uint256, TNetwork) {
    return companionNetworkData(config.getCurrentNetwork());
  }

  function companionNetworkData(TNetwork network) internal returns (uint256 chainId, TNetwork companionTNetwork) {
    companionTNetwork = config.getCompanionNetwork(network);
    config.switchTo(companionTNetwork);
    chainId = block.chainid;
  }
}
