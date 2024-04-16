// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { TContract, Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { TNetwork, DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { PostCheck_BridgeManager } from "./post-check/bridge-manager/PostCheck_BridgeManager.s.sol";
import { PostCheck_Gateway } from "./post-check/gateway/PostCheck_Gateway.s.sol";
import { Migration } from "./Migration.s.sol";
import { ScriptExtended } from "@fdk/extensions/ScriptExtended.s.sol";

contract PostChecker is Migration, PostCheck_BridgeManager, PostCheck_Gateway {
  using LibCompanionNetwork for *;

  function setUp() public virtual override(BaseMigration, Migration) {
    super.setUp();
  }

  function run() external {
    _loadSysContract();
    //  _validate_BridgeManager();
    _validate_Gateway();
  }

  function _deployLogic(TContract contractType) internal virtual override(BaseMigration, Migration) returns (address payable logic) {
    return super._deployLogic(contractType);
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args) internal virtual override(BaseMigration, Migration) {
    super._upgradeRaw(proxyAdmin, proxy, logic, args);
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
        || currentNetwork == DefaultNetwork.Local.key()
    ) {
      bridgeSlash = loadContract(Contract.BridgeSlash.key());
      bridgeReward = loadContract(Contract.BridgeReward.key());
      roninGateway = loadContract(Contract.RoninGatewayV3.key());
      bridgeTracking = loadContract(Contract.BridgeTracking.key());
      roninBridgeManager = loadContract(Contract.RoninBridgeManager.key());

      (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();
      mainchainGateway = CONFIG.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());
      mainchainBridgeManager = CONFIG.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());

      vm.makePersistent(bridgeSlash);
      vm.makePersistent(bridgeReward);
      vm.makePersistent(roninGateway);
      vm.makePersistent(roninBridgeManager);
      vm.makePersistent(mainchainGateway);
      vm.makePersistent(mainchainBridgeManager);
    } else {
      revert(string.concat("Unsupported network: ", currentNetwork.networkName()));
    }
  }
}
