// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Migration } from "../Migration.s.sol";
import { TContract, Contract } from "../utils/Contract.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { IWETH } from "@ronin/contracts/interfaces/IWETH.sol";
import { WETHDeploy } from "../contracts/token/WETHDeploy.s.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IGeneralConfigExtended } from "../interfaces/IGeneralConfigExtended.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { IMainchainGatewayV3, MainchainGatewayV3Deploy } from "../contracts/MainchainGatewayV3Deploy.s.sol";
import { WethUnwrapper, MainchainWethUnwrapperDeploy } from "../contracts/MainchainWethUnwrapperDeploy.s.sol";
import { IMainchainBridgeManager, MainchainBridgeManagerDeploy } from "../contracts/MainchainBridgeManagerDeploy.s.sol";

contract Migration_02_Deploy_MainchainBridge is Migration {
  using StdStyle for *;
  using LibCompanionNetwork for *;

  address private _weth;
  WethUnwrapper private _mainchainWethUnwrapper;
  IMainchainGatewayV3 private _mainchainGatewayV3;
  IMainchainBridgeManager private _mainchainBridgeManager;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.WETH.key(), new WETHDeploy());
  }

  function run() external {
    config.setLocalNetwork(IGeneralConfigExtended.LocalNetwork.Eth);

    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();
    _weth = loadContractOrDeploy(Contract.WETH.key());
    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainWethUnwrapper = new MainchainWethUnwrapperDeploy().run();

    _initMainchainGatewayV3();
    _initMainchainBridgeManager();
  }

  function _initMainchainBridgeManager() internal logFn("Init RoninBridgeManager") {
    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().mainchainBridgeManager;
    // address[] memory callbackRegisters = new address[](1);
    // callbackRegisters[0] = address(_bridgeSlash);
    // callbackRegisters[1] = address(_roninGatewayV3);

    uint256 companionChainId = network().companionChainId();
    (bool success,) = address(_mainchainBridgeManager).call(
      abi.encodeWithSignature(
        "initialize(uint256,uint256,uint256,address,address[],address[],address[],uint96[],uint8[],address[])",
        param.num,
        param.denom,
        companionChainId,
        address(_mainchainGatewayV3),
        param.callbackRegisters,
        param.bridgeOperators,
        param.governors,
        param.voteWeights,
        param.targetOptions,
        param.targets
      )
    );
    require(success, "MainchainBridgeManager: initialization failed");
  }

  function _initMainchainGatewayV3() internal logFn("Init MainchainGatewayV3") {
    ISharedArgument.MainchainGatewayV3Param memory param = config.sharedArguments().mainchainGatewayV3;

    uint256 companionChainId = network().companionChainId();
    (bool success,) = address(_mainchainGatewayV3).call(
      abi.encodeWithSignature(
        "initialize(address,address,uint256,uint256,uint256,uint256,address[][3],uint256[][4],uint8[])",
        param.roleSetter,
        IWETH(_weth),
        companionChainId,
        param.numerator,
        param.highTierVWNumerator,
        param.denominator,
        param.addresses,
        param.thresholds,
        param.standards
      )
    );
    require(success, "MainchainGatewayV3: initialization failed");
    (success,) = address(_mainchainGatewayV3).call(abi.encodeWithSignature("initializeV2(address)", address(_mainchainBridgeManager)));
    require(success, "MainchainGatewayV3: initialization V2 failed");
    (success,) = address(_mainchainGatewayV3).call(abi.encodeWithSignature("initializeV3()"));
    require(success, "MainchainGatewayV3: initialization V3 failed");
    (success,) = address(_mainchainGatewayV3).call(abi.encodeWithSignature("initializeV4(address)", payable(address(_mainchainWethUnwrapper))));
  }
}
