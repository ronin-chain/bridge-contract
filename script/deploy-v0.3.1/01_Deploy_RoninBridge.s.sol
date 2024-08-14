// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { StdStyle } from "forge-std/StdStyle.sol";
import { Migration } from "../Migration.s.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TContract, Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IGeneralConfigExtended } from "../interfaces/IGeneralConfigExtended.sol";
import { IBridgeSlash, BridgeSlashDeploy } from "../contracts/BridgeSlashDeploy.s.sol";
import { IBridgeReward, BridgeRewardDeploy } from "../contracts/BridgeRewardDeploy.s.sol";
import { IBridgeTracking, BridgeTrackingDeploy } from "../contracts/BridgeTrackingDeploy.s.sol";
import { IRoninGatewayV3, RoninGatewayV3Deploy } from "../contracts/RoninGatewayV3Deploy.s.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { HasContracts } from "@ronin/contracts/extensions/collections/HasContracts.sol";
import { RoninBridgeManagerConstructor, IRoninBridgeManager, RoninBridgeManagerDeploy } from "../contracts/RoninBridgeManagerDeploy.s.sol";
import { MockValidatorContract_OnlyTiming_ForHardhatTest } from "@ronin/contracts/mocks/ronin/MockValidatorContract_OnlyTiming_ForHardhatTest.sol";

contract Migration_01_Deploy_RoninBridge is Migration {
  using StdStyle for *;
  using LibProxy for *;

  IBridgeSlash private _bridgeSlash;
  IBridgeReward private _bridgeReward;
  IRoninGatewayV3 private _roninGatewayV3;
  IBridgeTracking private _bridgeTracking;
  IRoninBridgeManager private _roninBridgeManager;
  address private _validatorSet;

  function run() external {
    config.setLocalNetwork(IGeneralConfigExtended.LocalNetwork.Ronin);

    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;
    // address[] memory callbackRegisters = new address[](0);
    // callbackRegisters[0] = address(_bridgeSlash);
    // callbackRegisters[1] = address(_roninGatewayV3);

    _roninBridgeManager = IRoninBridgeManager(
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

    _roninGatewayV3 = new RoninGatewayV3Deploy().run();
    _bridgeSlash = new BridgeSlashDeploy().run();
    _bridgeReward = new BridgeRewardDeploy().run();
    _bridgeTracking = new BridgeTrackingDeploy().run();

    _initBridgeReward();
    _initBridgeSlash();
    _initRoninGatewayV3();
    _initBridgeTracking();
    // _initRoninBridgeManager();
  }

  function _initRoninBridgeManager() internal view logFn("Init RoninBridgeManager") {
    // ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().roninBridgeManager;
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
    (bool success,) = address(_bridgeTracking).call(
      abi.encodeWithSignature("initialize(address,address,uint256)", _roninGatewayV3, new MockValidatorContract_OnlyTiming_ForHardhatTest(200), 0)
    );
    require(success, "BridgeTracking initialize failed");

    (success,) = address(_bridgeTracking).call(
      abi.encodeWithSignature("initializeV3(address,address,address,address)", _roninBridgeManager, _bridgeSlash, _bridgeReward, address(0x0))
    );
    require(success, "BridgeTracking initializeV3 failed");
  }

  function _initBridgeReward() internal logFn("Init BridgeReward") {
    ISharedArgument.BridgeRewardParam memory param = config.sharedArguments().bridgeReward;
    (bool success,) = address(_bridgeReward).call(
      abi.encodeWithSignature(
        "initialize(address,address,address,address,address,uint256)",
        _roninBridgeManager,
        _bridgeTracking,
        _bridgeSlash,
        _validatorSet,
        address(0x0),
        param.rewardPerPeriod
      )
    );
    require(success, "BridgeReward initialize failed");
    // (success,) = address(_bridgeReward).call(abi.encodeWithSignature("initializeREP2()"));
    (success,) = address(_bridgeReward).call(abi.encodeWithSignature("initializeV2()"));
    require(success, "BridgeReward initializeV2 failed");
  }

  function _initBridgeSlash() internal logFn("Init BridgeSlash") {
    (bool success,) = address(_bridgeSlash).call(
      abi.encodeWithSignature("initialize(address,address,address,address)", _validatorSet, _roninBridgeManager, _bridgeTracking, address(0))
    );
    require(success, "BridgeSlash initialize failed");
  }

  function _initRoninGatewayV3() internal logFn("Init RoninGatewayV3") {
    ISharedArgument.RoninGatewayV3Param memory param = config.sharedArguments().roninGatewayV3;

    (bool success,) = address(_roninGatewayV3).call(
      abi.encodeWithSignature(
        "initialize(address,uint256,uint256,uint256,uint256,address[],address[][2],uint256[][2],uint8[])",
        param.roleSetter,
        param.numerator,
        param.denominator,
        param.trustedNumerator,
        param.trustedDenominator,
        param.withdrawalMigrators,
        param.packedAddresses,
        param.packedNumbers,
        param.standards
      )
    );
    require(success, "RoninGatewayV3 initialize failed");

    (success,) = address(_roninGatewayV3).call(abi.encodeWithSignature("initializeV3()", address(_roninBridgeManager)));
    require(success, "RoninGatewayV3 initializeV3 failed");

    address admin = payable(address(_roninGatewayV3)).getProxyAdmin();
    vm.startBroadcast(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(HasContracts.setContract, (ContractType.BRIDGE_TRACKING, address(_bridgeTracking)))
    );
    vm.stopBroadcast();
  }
}
