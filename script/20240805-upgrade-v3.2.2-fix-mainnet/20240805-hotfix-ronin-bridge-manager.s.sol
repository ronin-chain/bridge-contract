// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { Migration } from "script/Migration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { cheatBroadcast } from "@fdk/utils/Helpers.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import "@ronin/contracts/utils/CommonErrors.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";

contract Migration__20240805_HotFix_RoninBridgeManager is Migration {
  using LibProxy for *;

  function run() external {
    address roninBM = loadContract(Contract.RoninBridgeManager.key());
    address proxyAdmin = roninBM.getProxyAdmin();
    address bridgeSlash = loadContract(Contract.BridgeSlash.key());
    address roninGW = loadContract(Contract.RoninGatewayV3.key());

    address newRoninGWImpl = _deployLogic(Contract.RoninGatewayV3.key());

    // Cheat set admin slot to current bm
    vm.store(roninGW, LibProxy.ADMIN_SLOT, bytes32(uint256(uint160(roninBM))));
    // Cheat set impl slot to new bridge slash logic
    vm.store(bridgeSlash, LibProxy.IMPLEMENTATION_SLOT, bytes32(uint256(uint160(0xfc274EC92bBb1A1472884558d1B5CaaC6F8220Ee))));

    console.log("Proxy Admin", proxyAdmin);

    address prevImpl = roninBM.getProxyImplementation();

    console.log("Prev Impl", prevImpl);

    address hotfixImpl = _deployLogic(Contract.RoninBridgeManager.key());

    console.log("Hotfix Impl", hotfixImpl);

    cheatBroadcast(
      proxyAdmin,
      roninBM,
      0,
      abi.encodeCall(
        TransparentUpgradeableProxy.upgradeToAndCall,
        (hotfixImpl, abi.encodeWithSignature("hotfix__mapToken_setMinimumThresholds_registerCallbacks(address)", (newRoninGWImpl)))
      )
    );

    cheatBroadcast(proxyAdmin, roninBM, 0, abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (prevImpl)));

    address mainchainWBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address finalizedWBTC = 0x7E73630F81647bCFD7B1F2C04c1C662D17d4577e;
    address mappedWBTC = IRoninGatewayV3(roninGW).getMainchainToken(finalizedWBTC, 1).tokenAddr;
    assertTrue(mappedWBTC == mainchainWBTC);
    assertTrue(MinimumWithdrawal(roninGW).minimumThreshold(mainchainWBTC) == 16700);

    address deprecatedWBTC = 0xC13948b5325c11279F5B6cBA67957581d374E0F0;
    vm.expectRevert(abi.encodeWithSelector(ErrUnsupportedToken.selector));
    mappedWBTC = IRoninGatewayV3(roninGW).getMainchainToken(deprecatedWBTC, 1).tokenAddr;
    // assertTrue(MinimumWithdrawal(roninGW).minimumThreshold(mainchainWBTC) == 0);
  }
}
