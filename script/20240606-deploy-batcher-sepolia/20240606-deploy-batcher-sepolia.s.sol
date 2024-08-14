// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "script/contracts/MainchainBridgeManagerDeploy.s.sol";
import "script/contracts/MainchainWethUnwrapperDeploy.s.sol";
import "script/contracts/MainchainGatewayBatcherDeploy.s.sol";

import { Migration } from "../Migration.s.sol";

contract Migration__20240606_DeployBatcherSepolia is Migration {
  IMainchainBridgeManager _currMainchainBridgeManager;
  IMainchainBridgeManager _newMainchainBridgeManager;
  IMainchainGatewayV3 _currMainchainBridge;
  IMainchainGatewayBatcher _mainchainGatewayBatcher;

  address private _governor;
  address[] private _voters;

  address TESTNET_ADMIN = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;

  function setUp() public virtual override {
    super.setUp();
  }

  function run() public virtual onlyOn(Network.Sepolia.key()) {
    CONFIG.setAddress(network(), DefaultContract.ProxyAdmin.key(), TESTNET_ADMIN);

    // _currMainchainBridgeManager = MainchainBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));

    // _governor = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    // _voters.push(0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    // _voters.push(0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    // _voters.push(0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);

    // _changeTempAdmin();
    // _deployMainchainBridgeManager();
    // _upgradeBridgeMainchain();

    _currMainchainBridge = IMainchainGatewayV3(loadContract(Contract.MainchainGatewayV3.key()));
    // vm.stopBroadcast();
    // vm.startBroadcast(TESTNET_ADMIN);
    _mainchainGatewayBatcher =
      new MainchainGatewayBatcherDeploy().runWithArgs(abi.encodeWithSelector(IMainchainGatewayBatcher.initialize.selector, address(_currMainchainBridge)));
    // vm.stopBroadcast();
  }

  function _changeTempAdmin() internal {
    address pauseEnforcerProxy = loadContract(Contract.MainchainPauseEnforcer.key());
    address mainchainGatewayV3Proxy = loadContract(Contract.MainchainGatewayV3.key());

    vm.startBroadcast(0x968D0Cd7343f711216817E617d3f92a23dC91c07);
    (bool success,) = address(pauseEnforcerProxy).call(abi.encodeWithSignature("changeAdmin(address)", _currMainchainBridgeManager));
    require(success, "Failed to change admin of MainchainPauseEnforcer");
    (success,) = address(mainchainGatewayV3Proxy).call(abi.encodeWithSignature("changeAdmin(address)", _currMainchainBridgeManager));
    require(success, "Failed to change admin of MainchainGatewayV3");
    vm.stopBroadcast();
  }

  function _postCheck() internal pure override {
    console.log(StdStyle.green("Migration skipped"));
  }
}
