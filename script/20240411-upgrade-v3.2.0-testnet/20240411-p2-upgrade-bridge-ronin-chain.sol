// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "@ronin/script/contracts/RoninBridgeManagerDeploy.s.sol";

import "../BridgeMigration.sol";

contract Migration__20240409_P2_UpgradeBridgeRoninchain is BridgeMigration {
  ISharedArgument.SharedParameter _param;
  RoninBridgeManager _currRoninBridgeManager;
  RoninBridgeManager _newRoninBridgeManager;

  address private _governor;


  function setUp() public override {
    super.setUp();
  }

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    _governor = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _newRoninBridgeManager = RoninBridgeManager(address(0xdeadbeef)); // TODO: fulfill here
    _currRoninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));

    address bridgeRewardLogic = _deployLogic(Contract.BridgeReward.key());
    address bridgeSlashLogic = _deployLogic(Contract.BridgeSlash.key());
    address bridgeTrackingLogic = _deployLogic(Contract.BridgeTracking.key());
    address pauseEnforcerLogic = _deployLogic(Contract.RoninPauseEnforcer.key());
    address roninGatewayV3Logic = _deployLogic(Contract.RoninGatewayV3.key());

    address bridgeRewardProxy = _config.getAddressFromCurrentNetwork(Contract.BridgeReward.key());
    address bridgeSlashProxy = _config.getAddressFromCurrentNetwork(Contract.BridgeSlash.key());
    address bridgeTrackingProxy = _config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());
    address pauseEnforcerProxy = _config.getAddressFromCurrentNetwork(Contract.RoninPauseEnforcer.key());
    address roninGatewayV3Proxy = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    uint256 expiredTime = block.timestamp + 14 days;
    uint N = 10;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = bridgeRewardProxy;
    targets[1] = bridgeSlashProxy;
    targets[2] = bridgeTrackingProxy;
    targets[3] = pauseEnforcerProxy;
    targets[4] = roninGatewayV3Proxy;
    targets[5] = bridgeRewardProxy;
    targets[6] = bridgeSlashProxy;
    targets[7] = bridgeTrackingProxy;
    targets[8] = pauseEnforcerProxy;
    targets[9] = roninGatewayV3Proxy;

    calldatas[0] = abi.encodeWithSignature("upgradeTo(address)", bridgeRewardLogic);
    calldatas[1] = abi.encodeWithSignature("upgradeTo(address)", bridgeSlashLogic);
    calldatas[2] = abi.encodeWithSignature("upgradeTo(address)", bridgeTrackingLogic);
    calldatas[3] = abi.encodeWithSignature("upgradeTo(address)", pauseEnforcerLogic);
    calldatas[4] = abi.encodeWithSignature("upgradeTo(address)", roninGatewayV3Logic);
    calldatas[5] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[6] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[7] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[8] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[9] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    for (uint i; i < N; ++i) {
      gasAmounts[i] = 1_000_000;
    }

    vm.broadcast(_governor);
    address(_currRoninBridgeManager).call(
      abi.encodeWithSignature(
        "propose(uint256,uint256,address[],uint256[],bytes[],uint256[])",
        block.chainid, expiredTime, targets, values, calldatas, gasAmounts
      )
    );
  }
}
