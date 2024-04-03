// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";

import { ISharedArgument } from "@ronin/script/interfaces/ISharedArgument.sol";
import { LibSharedAddress } from "foundry-deployment-kit/libraries/LibSharedAddress.sol";

import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { PauseEnforcer } from "@ronin/contracts/ronin/gateway/PauseEnforcer.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { MockERC721 } from "@ronin/contracts/mocks/token/MockERC721.sol";
import { MockWrappedToken } from "@ronin/contracts/mocks/token/MockWrappedToken.sol";

import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

import { MainchainGatewayV3Deploy } from "@ronin/script/contracts/MainchainGatewayV3Deploy.s.sol";
import { MainchainBridgeManagerDeploy } from "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import { MainchainPauseEnforcerDeploy } from "@ronin/script/contracts/MainchainPauseEnforcerDeploy.s.sol";
import { WETHDeploy } from "@ronin/script/contracts/token/WETHDeploy.s.sol";
import { WRONDeploy } from "@ronin/script/contracts/token/WRONDeploy.s.sol";
import { AXSDeploy } from "@ronin/script/contracts/token/AXSDeploy.s.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";
import { MockERC721Deploy } from "@ronin/script/contracts/token/MockERC721Deploy.s.sol";

import { GeneralConfig } from "../GeneralConfig.sol";
import { Network } from "../utils/Network.sol";

contract DeploySepolia is BaseMigration {
  ISharedArgument.SharedParameter _param;

  PauseEnforcer _mainchainPauseEnforcer;
  MainchainGatewayV3 _mainchainGatewayV3;
  MainchainBridgeManager _mainchainBridgeManager;

  MockWrappedToken _mainchainWeth;
  MockERC20 _mainchainAxs;
  MockERC20 _mainchainSlp;
  MockERC20 _mainchainUsdc;
  MockERC721 _mainchainMockERC721;

  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    return "";
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    return payable(0x55ba00EeB8D8d33Df1b1985459D310b9CAfB19f2);
  }

  function setUp() public override {
    super.setUp();
  }

  function run() public {
    // function run() public onlyOn(Network.Sepolia.key()) {
    _deployContractsOnMainchain();
  }

  function _deployContractsOnMainchain() internal {
    _mainchainPauseEnforcer = new MainchainPauseEnforcerDeploy().run();
    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    _mainchainWeth = new WETHDeploy().run();
    _mainchainAxs = new AXSDeploy().run();
    _mainchainSlp = new SLPDeploy().run();
    _mainchainUsdc = new USDCDeploy().run();
    _mainchainMockERC721 = new MockERC721Deploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _mainchainProposalUtils = new MainchainBridgeAdminUtils(
      _param.test.governorPKs, _mainchainBridgeManager, _param.mainchainBridgeManager.governors[0]
    );
  }
}
