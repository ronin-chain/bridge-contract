// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PostCheck_Gateway_Quorum } from "script/post-check/gateway/quorum/PostCheck_Gateway_Quorum.s.sol";
import { PostCheck_BridgeManager } from "script/post-check/manager/PostCheck_BridgeManager.s.sol";
import { PostCheck_Gateway_DepositAndWithdraw_AfterRestrict } from
  "script/20241217-migrate-assets/postcheck/PostCheck_Gateway_DepositAndWithdraw_AfterRestrict.sol";

import { console } from "forge-std/console.sol";

import { Migration } from "script/Migration.s.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { TContract } from "@fdk/types/TContract.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { ProxyInterface } from "@fdk/libraries/LibDeploy.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { ScriptExtended } from "@fdk/extensions/ScriptExtended.s.sol";
import { IRuntimeConfig } from "@fdk/interfaces/configs/IRuntimeConfig.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

contract AssetMigration_PostChecker is Migration, PostCheck_BridgeManager, PostCheck_Gateway_Quorum, PostCheck_Gateway_DepositAndWithdraw_AfterRestrict {
  using LibCompanionNetwork for *;

  function run() external {
    vm.makePersistent(address(this));
    IRuntimeConfig.Option memory opt;
    opt = CONFIG.getRuntimeConfig();
    _originForkBlockNumber = opt.forkBlockNumber;

    _loadSysContract();

    _validate_Gateway_DepositAndWithdraw();
  }

  function _postCheck() internal virtual override(Migration, ScriptExtended) { }

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
  }

  function _loadRoninContracts() private {
    brSl = loadContract(Contract.BridgeSlash.key());
    brRw = loadContract(Contract.BridgeReward.key());
    ronGW = loadContract(Contract.RoninGatewayV3.key());
    brTk = loadContract(Contract.BridgeTracking.key());
    ronBM = loadContract(Contract.RoninBridgeManager.key());
  }
}
