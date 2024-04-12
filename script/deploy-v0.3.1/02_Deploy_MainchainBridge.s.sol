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
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { MainchainGatewayV3, MainchainGatewayV3Deploy } from "../contracts/MainchainGatewayV3Deploy.s.sol";
import { WethUnwrapper, MainchainWethUnwrapperDeploy } from "../contracts/MainchainWethUnwrapperDeploy.s.sol";
import { MainchainBridgeManager, MainchainBridgeManagerDeploy } from "../contracts/MainchainBridgeManagerDeploy.s.sol";

contract Migration_02_Deploy_MainchainBridge is Migration {
  using StdStyle for *;
  using LibCompanionNetwork for *;

  address private _weth;
  WethUnwrapper private _mainchainWethUnwrapper;
  MainchainGatewayV3 private _mainchainGatewayV3;
  MainchainBridgeManager private _mainchainBridgeManager;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.WETH.key(), new WETHDeploy());
  }

  function run() external {
    _isLocalETH = true;

    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();
    _weth = loadContractOrDeploy(Contract.WETH.key());
    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainWethUnwrapper = new MainchainWethUnwrapperDeploy().run();

    _initMainchainGatewayV3();
    _initMainchainBridgeManager();

    _isLocalETH = false;
  }

  function _initMainchainBridgeManager() internal logFn("Init RoninBridgeManager") {
    ISharedArgument.BridgeManagerParam memory param = config.sharedArguments().mainchainBridgeManager;
    // address[] memory callbackRegisters = new address[](1);
    // callbackRegisters[0] = address(_bridgeSlash);
    // callbackRegisters[1] = address(_roninGatewayV3);

    uint256 companionChainId = network().companionChainId();
    _mainchainBridgeManager.initialize({
      num: param.num,
      denom: param.denom,
      roninChainId: companionChainId,
      bridgeContract: address(_mainchainGatewayV3),
      callbackRegisters: param.callbackRegisters,
      bridgeOperators: param.bridgeOperators,
      governors: param.governors,
      voteWeights: param.voteWeights,
      targetOptions: param.targetOptions,
      targets: param.targets
    });
  }

  function _initMainchainGatewayV3() internal logFn("Init MainchainGatewayV3") {
    ISharedArgument.MainchainGatewayV3Param memory param = config.sharedArguments().mainchainGatewayV3;

    uint256 companionChainId = network().companionChainId();
    _mainchainGatewayV3.initialize(
      param.roleSetter,
      IWETH(_weth),
      companionChainId,
      param.numerator,
      param.highTierVWNumerator,
      param.denominator,
      param.addresses,
      param.thresholds,
      param.standards
    );
    _mainchainGatewayV3.initializeV2(address(_mainchainBridgeManager));
    _mainchainGatewayV3.initializeV3();
    _mainchainGatewayV3.initializeV4(payable(address(_mainchainWethUnwrapper)));
  }
}
