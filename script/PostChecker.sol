// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { TContract, Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { TNetwork, DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { PostCheck_BridgeManager } from "./post-check/manager/PostCheck_BridgeManager.s.sol";
import { PostCheck_Gateway } from "./post-check/gateway/PostCheck_Gateway.s.sol";
import { Migration } from "./Migration.s.sol";
import { ScriptExtended } from "@fdk/extensions/ScriptExtended.s.sol";
import { ProxyInterface } from "@fdk/libraries/LibDeploy.sol";
import { IRuntimeConfig } from "@fdk/interfaces/configs/IRuntimeConfig.sol";

contract PostChecker is Migration, PostCheck_BridgeManager, PostCheck_Gateway {
  using LibCompanionNetwork for *;

  function run() external {
    IRuntimeConfig.Option memory opt;
    opt = CONFIG.getRuntimeConfig();
    _originForkBlockNumber = opt.forkBlockNumber;

    _loadSysContract();
    _validate_Gateway();
    _validate_BridgeManager();
  }

  function _deployLogic(
    TContract contractType
  ) internal virtual override(BaseMigration, Migration) returns (address payable logic) {
    return super._deployLogic(contractType);
  }

  function _upgradeCallback(
    address proxy,
    address logic,
    uint256 callValue,
    bytes memory callData,
    ProxyInterface proxyInterface
  ) internal virtual override(BaseMigration, Migration) {
    super._upgradeCallback(proxy, logic, callValue, callData, proxyInterface);
  }

  function _postCheck() internal virtual override(ScriptExtended, Migration) {
    super._postCheck();
  }

  function _getProxyAdmin() internal virtual override(BaseMigration, Migration) returns (address payable) {
    return super._getProxyAdmin();
  }

  function _deployProxy(TContract contractType, bytes memory args) internal virtual override(BaseMigration, Migration) returns (address payable) {
    return super._deployProxy(contractType, args);
  }

  function _loadSysContract() private {
    TNetwork currentNetwork = network();
    if (
      currentNetwork == DefaultNetwork.RoninMainnet.key() || currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == Network.RoninDevnet.key()
        || currentNetwork == DefaultNetwork.LocalHost.key()
    ) {
      _loadRoninContracts();

      (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();
      ethGW = CONFIG.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());
      ethBM = CONFIG.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
    } else {
      ethGW = loadContract(Contract.MainchainGatewayV3.key());
      ethBM = loadContract(Contract.MainchainBridgeManager.key());

      console.log("Mainchain Bridge Manager Logic:", LibProxy.getProxyImplementation(ethBM));
      (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();

      uint256 originForkBlockNumber = config.getRuntimeConfig().forkBlockNumber;
      uint256 originForkId = config.getForkId(companionNetwork, originForkBlockNumber);
      config.switchTo(originForkId);

      _loadRoninContracts();
    }

    _markSysContractsAsPersistent();
  }

  function _loadRoninContracts() private {
    brSl = loadContract(Contract.BridgeSlash.key());
    brRw = loadContract(Contract.BridgeReward.key());
    ronGW = loadContract(Contract.RoninGatewayV3.key());
    brTk = loadContract(Contract.BridgeTracking.key());
    ronBM = loadContract(Contract.RoninBridgeManager.key());
  }

  function _markSysContractsAsPersistent() internal { }
}
