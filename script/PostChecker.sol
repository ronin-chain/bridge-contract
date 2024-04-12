// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { TNetwork, DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { PostCheck_BridgeManager } from "./post-check/bridge-manager/PostCheck_BridgeManager.s.sol";

abstract contract PostChecker is BaseMigration, PostCheck_BridgeManager {
  using LibCompanionNetwork for *;

  function _postCheck() internal override {
    _loadSysContract();
    _validate_BridgeManager();
  }

  function _loadSysContract() private {
    TNetwork currentNetwork = network();
    if (
      currentNetwork == DefaultNetwork.RoninMainnet.key() || currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == Network.RoninDevnet.key()
        || currentNetwork == DefaultNetwork.Local.key()
    ) {
      __bridgeSlash = loadContract(Contract.BridgeSlash.key());
      __bridgeReward = loadContract(Contract.BridgeReward.key());
      _gateway[block.chainid] = loadContract(Contract.RoninGatewayV3.key());
      _manager[block.chainid] = loadContract(Contract.RoninBridgeManager.key());

      (uint256 companionChainId, TNetwork companionNetwork) = currentNetwork.companionNetworkData();
      _gateway[companionChainId] = CONFIG.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());
      _manager[companionChainId] = CONFIG.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
    } else {
      revert(string.concat("Unsupported network: ", currentNetwork.networkName()));
    }
  }
}
