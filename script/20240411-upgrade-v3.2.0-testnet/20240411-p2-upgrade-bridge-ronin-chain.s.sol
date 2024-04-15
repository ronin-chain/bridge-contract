// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "@ronin/script/contracts/RoninBridgeManagerDeploy.s.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import "./20240411-deploy-bridge-manager-helper.s.sol";
import "./20240411-helper.s.sol";

contract Migration__20240409_P2_UpgradeBridgeRoninchain is Migration__20240409_Helper, Migration__2024041_DeployRoninBridgeManagerHelper {
  ISharedArgument.SharedParameter _param;

  function setUp() public virtual override {
    super.setUp();
  }

  function run() public virtual onlyOn(DefaultNetwork.RoninTestnet.key()) {
    _currRoninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _newRoninBridgeManager = _deployRoninBridgeManager();

    _governor = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _voters.push(0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    _voters.push(0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    _voters.push(0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);

    _changeAdminOfEnforcer();
    _upgradeBridgeRoninchain();
  }

  function _changeAdminOfEnforcer() private {
    RoninBridgeManager roninGA = RoninBridgeManager(0x53Ea388CB72081A3a397114a43741e7987815896);
    address pauseEnforcerProxy = config.getAddressFromCurrentNetwork(Contract.RoninPauseEnforcer.key());

    uint256 expiredTime = block.timestamp + 14 days;
    uint N = 1;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = pauseEnforcerProxy;
    calldatas[0] = abi.encodeWithSignature("changeAdmin(address)", address(_currRoninBridgeManager));
    gasAmounts[0] = 1_000_000;

    LegacyProposalDetail memory proposal;
    proposal.nonce = roninGA.round(block.chainid) + 1;
    proposal.chainId = block.chainid;
    proposal.expiryTimestamp = expiredTime;
    proposal.targets = targets;
    proposal.values = values;
    proposal.calldatas = calldatas;
    proposal.gasAmounts = gasAmounts;

    vm.broadcast(_governor);
    address(roninGA).call(
      abi.encodeWithSignature(
        "proposeProposalForCurrentNetwork(uint256,address[],uint256[],bytes[],uint256[],uint8)",
        // proposal.chainId,
        proposal.expiryTimestamp,
        proposal.targets,
        proposal.values,
        proposal.calldatas,
        proposal.gasAmounts,
        Ballot.VoteType.For
      )
    );

    for (uint i; i < _voters.length; ++i) {
      vm.broadcast(_voters[i]);
      address(roninGA).call(
        abi.encodeWithSignature(
          "castProposalVoteForCurrentNetwork((uint256,uint256,uint256,address[],uint256[],bytes[],uint256[]),uint8)", proposal, Ballot.VoteType.For
        )
      );
    }
  }

  function _upgradeBridgeRoninchain() private {
    address bridgeRewardLogic = _deployLogic(Contract.BridgeReward.key());
    address bridgeSlashLogic = _deployLogic(Contract.BridgeSlash.key());
    address bridgeTrackingLogic = _deployLogic(Contract.BridgeTracking.key());
    address pauseEnforcerLogic = _deployLogic(Contract.RoninPauseEnforcer.key());
    address roninGatewayV3Logic = _deployLogic(Contract.RoninGatewayV3.key());

    address bridgeRewardProxy = config.getAddressFromCurrentNetwork(Contract.BridgeReward.key());
    address bridgeSlashProxy = config.getAddressFromCurrentNetwork(Contract.BridgeSlash.key());
    address bridgeTrackingProxy = config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());
    address pauseEnforcerProxy = config.getAddressFromCurrentNetwork(Contract.RoninPauseEnforcer.key());
    address roninGatewayV3Proxy = config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    uint256 expiredTime = block.timestamp + 14 days;
    uint N = 11;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = bridgeRewardProxy;
    targets[1] = bridgeSlashProxy;
    targets[2] = bridgeTrackingProxy;
    targets[3] = roninGatewayV3Proxy;
    targets[4] = bridgeRewardProxy;
    targets[5] = bridgeSlashProxy;
    targets[6] = bridgeTrackingProxy;
    targets[7] = roninGatewayV3Proxy;
    targets[8] = roninGatewayV3Proxy;
    targets[9] = pauseEnforcerProxy;
    targets[10] = pauseEnforcerProxy;

    calldatas[0] = abi.encodeWithSignature("upgradeTo(address)", bridgeRewardLogic);
    calldatas[1] = abi.encodeWithSignature("upgradeTo(address)", bridgeSlashLogic);
    calldatas[2] = abi.encodeWithSignature("upgradeTo(address)", bridgeTrackingLogic);
    calldatas[3] = abi.encodeWithSignature("upgradeTo(address)", roninGatewayV3Logic);
    calldatas[4] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[5] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[6] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[7] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)",
      (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newRoninBridgeManager)))
    );
    calldatas[8] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));
    calldatas[9] = abi.encodeWithSignature("upgradeTo(address)", pauseEnforcerLogic);
    calldatas[10] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    for (uint i; i < N; ++i) {
      gasAmounts[i] = 1_000_000;
    }

    LegacyProposalDetail memory proposal;
    proposal.nonce = _currRoninBridgeManager.round(block.chainid) + 1;
    proposal.chainId = block.chainid;
    proposal.expiryTimestamp = expiredTime;
    proposal.targets = targets;
    proposal.values = values;
    proposal.calldatas = calldatas;
    proposal.gasAmounts = gasAmounts;

    _helperProposeForCurrentNetwork(proposal);
    _helperVoteForCurrentNetwork(proposal);
  }
}
