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

contract Migration__20240409_P1_DeployRoninBridgeManager is BridgeMigration {
  ISharedArgument.SharedParameter _param;
  RoninBridgeManager _roninBridgeManager;

  function setUp() public override {
    super.setUp();
  }

  function run() public  onlyOn(DefaultNetwork.RoninTestnet.key()) {
    ISharedArgument.SharedParameter memory param;

    param.roninBridgeManager.num = 7;
    param.roninBridgeManager.denom = 10;
    param.roninBridgeManager.roninChainId = block.chainid;
    param.roninBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
    param.roninBridgeManager.bridgeContract = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
    param.roninBridgeManager.bridgeOperators = new address[](4);
    param.roninBridgeManager.bridgeOperators[0] = 0x2e82D2b56f858f79DeeF11B160bFC4631873da2B;
    param.roninBridgeManager.bridgeOperators[1] = 0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb;
    param.roninBridgeManager.bridgeOperators[2] = 0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c;
    param.roninBridgeManager.bridgeOperators[3] = 0xcc5Fc5B6c8595F56306Da736F6CD02eD9141C84A;

    param.roninBridgeManager.governors = new address[](4);
    param.roninBridgeManager.governors[0] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    param.roninBridgeManager.governors[1] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    param.roninBridgeManager.governors[2] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    param.roninBridgeManager.governors[3] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    param.roninBridgeManager.voteWeights = new uint96[](4);
    param.roninBridgeManager.voteWeights[0] = 100;
    param.roninBridgeManager.voteWeights[1] = 100;
    param.roninBridgeManager.voteWeights[2] = 100;
    param.roninBridgeManager.voteWeights[3] = 100;

    param.roninBridgeManager.targetOptions = new GlobalProposal.TargetOption[](4);
    param.roninBridgeManager.targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    param.roninBridgeManager.targetOptions[1] = GlobalProposal.TargetOption.BridgeReward;
    param.roninBridgeManager.targetOptions[2] = GlobalProposal.TargetOption.BridgeSlash;
    param.roninBridgeManager.targetOptions[3] = GlobalProposal.TargetOption.BridgeTracking;

    param.roninBridgeManager.targets = new address[](4);
    param.roninBridgeManager.targets[0] = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
    param.roninBridgeManager.targets[1] = _config.getAddressFromCurrentNetwork(Contract.BridgeReward.key());
    param.roninBridgeManager.targets[2] = _config.getAddressFromCurrentNetwork(Contract.BridgeSlash.key());
    param.roninBridgeManager.targets[3] = _config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());

    _roninBridgeManager = RoninBridgeManager(new RoninBridgeManagerDeploy().overrideArgs(
      abi.encodeCall(
        RoninBridgeManagerConstructor.initialize,
        (
          param.roninBridgeManager.num,
          param.roninBridgeManager.denom,
          param.roninBridgeManager.roninChainId,
          param.roninBridgeManager.expiryDuration,
          param.roninBridgeManager.bridgeContract,
          param.roninBridgeManager.callbackRegisters,
          param.roninBridgeManager.bridgeOperators,
          param.roninBridgeManager.governors,
          param.roninBridgeManager.voteWeights,
          param.roninBridgeManager.targetOptions,
          param.roninBridgeManager.targets
        )
      )
    ).run());
  }
}
