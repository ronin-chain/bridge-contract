// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Base_Test } from "../../Base.t.sol";
import { LibSharedAddress } from "foundry-deployment-kit/libraries/LibSharedAddress.sol";
import { ISharedArgument } from "@ronin/script/interfaces/ISharedArgument.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { MockWrappedToken } from "@ronin/contracts/mocks/token/MockWrappedToken.sol";

import { RoninBridgeManagerDeploy } from "@ronin/script/contracts/RoninBridgeManagerDeploy.s.sol";
import { RoninGatewayV3Deploy } from "@ronin/script/contracts/RoninGatewayV3Deploy.s.sol";
import { BridgeTrackingDeploy } from "@ronin/script/contracts/BridgeTrackingDeploy.s.sol";
import { BridgeSlashDeploy } from "@ronin/script/contracts/BridgeSlashDeploy.s.sol";
import { BridgeRewardDeploy } from "@ronin/script/contracts/BridgeRewardDeploy.s.sol";
import { MainchainGatewayV3Deploy } from "@ronin/script/contracts/MainchainGatewayV3Deploy.s.sol";
import { MainchainBridgeManagerDeploy } from "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import { WETHDeploy } from "@ronin/script/contracts/token/WETHDeploy.s.sol";
import { AXSDeploy } from "@ronin/script/contracts/token/AXSDeploy.s.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";

contract BaseIntegration_Test is Base_Test {
  ISharedArgument.SharedParameter _param;

  RoninBridgeManager _roninBridgeManager;
  RoninGatewayV3 _roninGatewayV3;
  BridgeTracking _bridgeTracking;
  BridgeSlash _bridgeSlash;
  BridgeReward _bridgeReward;
  MainchainGatewayV3 _mainchainGatewayV3;
  MainchainBridgeManager _mainchainBridgeManager;

  MockWrappedToken _weth;
  MockERC20 _axs;
  MockERC20 _slp;
  MockERC20 _usdc;

  function setUp() public virtual {
    _roninGatewayV3 = new RoninGatewayV3Deploy().run();
    _bridgeTracking = new BridgeTrackingDeploy().run();
    _bridgeSlash = new BridgeSlashDeploy().run();
    _bridgeReward = new BridgeRewardDeploy().run();
    _roninBridgeManager = new RoninBridgeManagerDeploy().run();

    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    _weth = new WETHDeploy().run();
    _axs = new AXSDeploy().run();
    _slp = new SLPDeploy().run();
    _usdc = new USDCDeploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
  }
}
