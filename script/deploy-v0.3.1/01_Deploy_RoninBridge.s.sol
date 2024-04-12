// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Migration } from "../Migration.s.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TContract, Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { BridgeSlash, BridgeSlashDeploy } from "../contracts/BridgeSlashDeploy.s.sol";
import { BridgeReward, BridgeRewardDeploy } from "../contracts/BridgeRewardDeploy.s.sol";
import { BridgeTracking, BridgeTrackingDeploy } from "../contracts/BridgeTrackingDeploy.s.sol";
import { RoninGatewayV3, RoninGatewayV3Deploy } from "../contracts/RoninGatewayV3Deploy.s.sol";
import { RoninBridgeManagerConstructor, RoninBridgeManager, RoninBridgeManagerDeploy } from "../contracts/RoninBridgeManagerDeploy.s.sol";

contract Migration_01_Deploy_RoninBridge is Migration {
  using StdStyle for *;

  BridgeSlash private _bridgeSlash;
  BridgeReward private _bridgeReward;
  RoninGatewayV3 private _roninGatewayV3;
  BridgeTracking private _bridgeTracking;
  RoninBridgeManager private _roninBridgeManager;
  address private _validatorSet;

  function run() external {
    _roninGatewayV3 = new RoninGatewayV3Deploy().run();
    _bridgeSlash = new BridgeSlashDeploy().run();
    _bridgeReward = new BridgeRewardDeploy().run();
    _bridgeTracking = new BridgeTrackingDeploy().run();

    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;
    address[] memory callbackRegisters = new address[](1);
    callbackRegisters[0] = address(_bridgeSlash);
    callbackRegisters[1] = address(_roninGatewayV3);

    _roninBridgeManager = RoninBridgeManager(
      new RoninBridgeManagerDeploy().overrideArgs(
        abi.encodeCall(
          RoninBridgeManagerConstructor.initialize,
          (
            param.num,
            param.denom,
            param.roninChainId,
            param.expiryDuration,
            param.bridgeContract,
            param.callbackRegisters,
            param.bridgeOperators,
            param.governors,
            param.voteWeights,
            param.targetOptions,
            param.targets
          )
        )
      ).run()
    );

    _initBridgeReward();
    _initBridgeSlash();
    _initRoninGatewayV3();
    _initBridgeTracking();
    // _initRoninBridgeManager();
  }

  function _initRoninBridgeManager() internal logFn("Init RoninBridgeManager") {
    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;
    // address[] memory callbackRegisters = new address[](1);
    // callbackRegisters[0] = address(_bridgeSlash);
    // callbackRegisters[1] = address(_roninGatewayV3);

    // _roninBridgeManager.initialize({
    //   num: param.num,
    //   denom: param.denom,
    //   roninChainId: block.chainid,
    //   expiryDuration: param.expiryDuration,
    //   bridgeContract: address(_roninGatewayV3),
    //   callbackRegisters: param.callbackRegisters,
    //   bridgeOperators: param.bridgeOperators,
    //   governors: param.governors,
    //   voteWeights: param.voteWeights,
    //   targetOptions: param.targetOptions,
    //   targets: param.targets
    // });
  }

  function _initBridgeTracking() internal logFn("Init BridgeTracking") {
    _bridgeTracking.initialize({ bridgeContract: address(_roninGatewayV3), validatorContract: _validatorSet, startedAtBlock_: 0 });
    _bridgeTracking.initializeV3({
      bridgeManager: address(_roninBridgeManager),
      bridgeSlash: address(_bridgeSlash),
      bridgeReward: address(_bridgeReward),
      dposGA: address(0x0)
    });
  }

  function _initBridgeReward() internal logFn("Init BridgeReward") {
    ISharedArgument.BridgeRewardParam memory param = config.sharedArguments().bridgeReward;
    _bridgeReward.initialize({
      bridgeManagerContract: address(_roninBridgeManager),
      bridgeTrackingContract: address(_bridgeTracking),
      bridgeSlashContract: address(_bridgeSlash),
      validatorSetContract: _validatorSet,
      dposGA: address(0x0),
      rewardPerPeriod: param.rewardPerPeriod
    });
    // _bridgeReward.initializeREP2();
    _bridgeReward.initializeV2();
  }

  function _initBridgeSlash() internal logFn("Init BridgeSlash") {
    _bridgeSlash.initialize({
      validatorContract: _validatorSet,
      bridgeManagerContract: address(_roninBridgeManager),
      bridgeTrackingContract: address(_bridgeTracking),
      dposGA: address(0x0)
    });
  }

  function _initRoninGatewayV3() internal logFn("Init RoninGatewayV3") {
    ISharedArgument.RoninGatewayV3Param memory param = config.sharedArguments().roninGatewayV3;

    _roninGatewayV3.initialize(
      param.roleSetter,
      param.numerator,
      param.denominator,
      param.trustedNumerator,
      param.trustedDenominator,
      param.withdrawalMigrators,
      param.packedAddresses,
      param.packedNumbers,
      param.standards
    );
    _roninGatewayV3.initializeV3(address(_roninBridgeManager));
  }
}
