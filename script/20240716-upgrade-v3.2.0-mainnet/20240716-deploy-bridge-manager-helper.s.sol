// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { IGeneralConfigExtended } from "../interfaces/IGeneralConfigExtended.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "script/contracts/RoninBridgeManagerDeploy.s.sol";

import { Migration } from "../Migration.s.sol";

abstract contract Migration__20240716_DeployRoninBridgeManagerHelper is Migration {
  using LibProxy for *;

  IRoninBridgeManager _newRoninBridgeManager;

  function _deployRoninBridgeManager() internal returns (IRoninBridgeManager) {
    address currRoninBridgeManager = loadContract(Contract.RoninBridgeManager.key());
    console.log("Current Ronin Bridge Manager:", currRoninBridgeManager);

    ISharedArgument.SharedParameter memory param;

    {
      (address[] memory currGovernors, address[] memory currOperators, uint96[] memory currWeights) =
        IRoninBridgeManager(currRoninBridgeManager).getFullBridgeOperatorInfos();

      param.roninBridgeManager.num = 7;
      param.roninBridgeManager.denom = 10;
      param.roninBridgeManager.roninChainId = block.chainid;
      param.roninBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
      param.roninBridgeManager.bridgeContract = loadContract(Contract.RoninGatewayV3.key());

      uint totalCurrGovernors = currGovernors.length;
      param.roninBridgeManager.bridgeOperators = new address[](totalCurrGovernors);
      param.roninBridgeManager.governors = new address[](totalCurrGovernors);
      param.roninBridgeManager.voteWeights = new uint96[](totalCurrGovernors);

      for (uint i = 0; i < totalCurrGovernors; i++) {
        param.roninBridgeManager.bridgeOperators[i] = currOperators[i];
        param.roninBridgeManager.governors[i] = currGovernors[i];
        param.roninBridgeManager.voteWeights[i] = currWeights[i];
      }
    }

    param.roninBridgeManager.targetOptions = new GlobalProposal.TargetOption[](5);
    param.roninBridgeManager.targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    param.roninBridgeManager.targetOptions[1] = GlobalProposal.TargetOption.BridgeReward;
    param.roninBridgeManager.targetOptions[2] = GlobalProposal.TargetOption.BridgeSlash;
    param.roninBridgeManager.targetOptions[3] = GlobalProposal.TargetOption.BridgeTracking;
    param.roninBridgeManager.targetOptions[4] = GlobalProposal.TargetOption.PauseEnforcer;

    param.roninBridgeManager.targets = new address[](5);
    param.roninBridgeManager.targets[0] = loadContract(Contract.RoninGatewayV3.key());
    param.roninBridgeManager.targets[1] = loadContract(Contract.BridgeReward.key());
    param.roninBridgeManager.targets[2] = loadContract(Contract.BridgeSlash.key());
    param.roninBridgeManager.targets[3] = loadContract(Contract.BridgeTracking.key());
    param.roninBridgeManager.targets[4] = loadContract(Contract.RoninPauseEnforcer.key());

    _newRoninBridgeManager = IRoninBridgeManager(
      new RoninBridgeManagerDeploy().overrideArgs(
        abi.encodeCall(
          RoninBridgeManagerConstructor.initialize,
          (
            param.roninBridgeManager.num,
            param.roninBridgeManager.denom,
            param.roninBridgeManager.roninChainId,
            param.roninBridgeManager.expiryDuration,
            param.roninBridgeManager.bridgeContract,
            new address[](0),
            param.roninBridgeManager.bridgeOperators,
            param.roninBridgeManager.governors,
            param.roninBridgeManager.voteWeights,
            param.roninBridgeManager.targetOptions,
            param.roninBridgeManager.targets
          )
        )
      ).run()
    );

    address proxyAdmin = LibProxy.getProxyAdmin(payable(address(_newRoninBridgeManager)));

    console.log("Finish deploy Ronin Bridge Manager");

    // // transfer admin to self
    // vm.broadcast(proxyAdmin);
    // TransparentUpgradeableProxy(payable(address(_newRoninBridgeManager))).changeAdmin(address(_newRoninBridgeManager));

    return _newRoninBridgeManager;
  }
}
