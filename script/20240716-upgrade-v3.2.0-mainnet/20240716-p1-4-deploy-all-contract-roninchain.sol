// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { WBTC } from "src/tokens/erc20/WBTC.sol";

import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import "script/contracts/MainchainBridgeManagerDeploy.s.sol";
import "script/contracts/MainchainWethUnwrapperDeploy.s.sol";

import "./20240716-deploy-wbtc-helper.s.sol";

contract Migration__20240716_P1_4_DeployAllContract_Mainchain is Migration {
  IMainchainBridgeManager _newMainchainBridgeManager;
  IMainchainBridgeManager _currMainchainBridgeManager;

  function run() public returns (WBTC instance) {
    _scrDeployMainchainBridgeManager();
    _scrDeployWeth();
    _scrDeployMainchainGatewayLogic();
  }

  function _scrDeployMainchainBridgeManager() internal {
    _currMainchainBridgeManager = IMainchainBridgeManager(0xa71456fA88a5f6a4696D0446E690Db4a5913fab0);

    ISharedArgument.SharedParameter memory param;

    {
      (address[] memory currGovernors, address[] memory currOperators, uint96[] memory currWeights) = _currMainchainBridgeManager.getFullBridgeOperatorInfos();
      uint totalCurrGovernors = currGovernors.length;
      param.mainchainBridgeManager.bridgeOperators = new address[](totalCurrGovernors);
      param.mainchainBridgeManager.governors = new address[](totalCurrGovernors);
      param.mainchainBridgeManager.voteWeights = new uint96[](totalCurrGovernors);

      for (uint i = 0; i < totalCurrGovernors; i++) {
        param.mainchainBridgeManager.bridgeOperators[i] = currOperators[i];
        param.mainchainBridgeManager.governors[i] = currGovernors[i];
        param.mainchainBridgeManager.voteWeights[i] = currWeights[i];
      }
    }

    param.mainchainBridgeManager.num = 7;
    param.mainchainBridgeManager.denom = 10;
    param.mainchainBridgeManager.roninChainId = 2020;
    param.mainchainBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
    param.mainchainBridgeManager.bridgeContract = loadContract(Contract.MainchainGatewayV3.key());

    param.mainchainBridgeManager.targetOptions = new GlobalProposal.TargetOption[](2);
    param.mainchainBridgeManager.targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    param.mainchainBridgeManager.targetOptions[1] = GlobalProposal.TargetOption.PauseEnforcer;

    param.mainchainBridgeManager.targets = new address[](2);
    param.mainchainBridgeManager.targets[0] = loadContract(Contract.MainchainGatewayV3.key());
    param.mainchainBridgeManager.targets[1] = loadContract(Contract.MainchainPauseEnforcer.key());

    _newMainchainBridgeManager = IMainchainBridgeManager(
      new MainchainBridgeManagerDeploy().overrideArgs(
        abi.encodeCall(
          _newMainchainBridgeManager.initialize,
          (
            param.mainchainBridgeManager.num,
            param.mainchainBridgeManager.denom,
            param.mainchainBridgeManager.roninChainId,
            param.mainchainBridgeManager.bridgeContract,
            new address[](0),
            param.mainchainBridgeManager.bridgeOperators,
            param.mainchainBridgeManager.governors,
            param.mainchainBridgeManager.voteWeights,
            param.mainchainBridgeManager.targetOptions,
            param.mainchainBridgeManager.targets
          )
        )
      ).run()
    );
  }

  function _scrDeployWeth() internal {
    address weth = loadContract(Contract.WETH.key());
    address wethUnwrapper = new MainchainWethUnwrapperDeploy().overrideArgs(abi.encode(weth)).run();
  }

  function _scrDeployMainchainGatewayLogic() internal {
    address mainchainGatewayV3Logic = _deployLogic(Contract.MainchainGatewayV3.key());
  }
}
