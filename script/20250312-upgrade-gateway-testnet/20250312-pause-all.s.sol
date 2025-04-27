// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { IMainchainGatewayV3 } from "script/interfaces/IMainchainGatewayV3.sol";
import { AssetMigration } from "@ronin/contracts/extensions/AssetMigration.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "script/utils/Network.sol";

import { Migration } from "script/Migration.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { PauseEnforcer } from "@ronin/contracts/ronin/gateway/PauseEnforcer.sol";
import { IRoninGatewayV3 } from "script/interfaces/IRoninGatewayV3.sol";

contract Migration__20250312_Pause_All is Migration {
  function run() public virtual {
    IRoninGatewayV3 ronGW = IRoninGatewayV3(loadContract(Contract.RoninGatewayV3.key()));
    PauseEnforcer ronPauseEnforcer = PauseEnforcer(ronGW.emergencyPauser());

    uint8 forbidAll = type(uint8).max;

    address admin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;

    // vm.startBroadcast(admin);

    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.depositFor.selector, forbidAll);
    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.tryBulkDepositFor.selector, forbidAll);
    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalFor.selector, forbidAll);
    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.bulkRequestWithdrawalFor.selector, forbidAll);
    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.requestWithdrawalSignatures.selector, forbidAll);
    // // ronPauseEnforcer.triggerRestrict(IRoninGatewayV3.bulkSubmitWithdrawalSignatures.selector, forbidAll);

    // ronPauseEnforcer.triggerPause();

    // vm.stopBroadcast();

    TNetwork companionNetwork = config.getCompanionNetwork(network());
    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(companionNetwork);

    IMainchainGatewayV3 ethGw = IMainchainGatewayV3(loadContract(Contract.MainchainGatewayV3.key()));
    PauseEnforcer ethPauseEnforcer = PauseEnforcer(ethGw.emergencyPauser());

    vm.startBroadcast(admin);

    // ethPauseEnforcer.grantRole(ethPauseEnforcer.SENTRY_ROLE(), admin);

    // ethPauseEnforcer.triggerRestrict(IMainchainGatewayV3.requestDepositFor.selector, forbidAll);
    // ethPauseEnforcer.triggerRestrict(IMainchainGatewayV3.submitWithdrawal.selector, forbidAll);

    ethPauseEnforcer.triggerUnpause();

    vm.stopBroadcast();

    switchBack(prvNetwork, prvForkId);
  }
}
