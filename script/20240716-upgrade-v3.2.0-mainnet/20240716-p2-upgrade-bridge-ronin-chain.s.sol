// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "script/contracts/RoninBridgeManagerDeploy.s.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import "./20240716-deploy-bridge-manager-helper.s.sol";
import "./20240716-helper.s.sol";
import "./wbtc-threshold.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

contract Migration__20240716_P2_UpgradeBridgeRoninchain is
  Migration__20240716_Helper,
  Migration__20240716_DeployRoninBridgeManagerHelper,
  Migration__MapToken_WBTC_Threshold
{
  using StdStyle for *;

  ISharedArgument.SharedParameter _param;
  LegacyProposalDetail _roninProposal;

  function run() public virtual onlyOn(DefaultNetwork.RoninMainnet.key()) {
    console.log("=== Starting migration Roninchain".bold().cyan());
    _currRoninBridgeManager = IRoninBridgeManager(0x5FA49E6CA54a9daa8eCa4F403ADBDE5ee075D84a);
    _newRoninBridgeManager = IRoninBridgeManager(0x2ae89936FC398AeA23c63dB2404018fE361A8628);
    _proposer = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // SM Governor

    (address[] memory currGovernors,,) = _currRoninBridgeManager.getFullBridgeOperatorInfos();
    for (uint i = 0; i < currGovernors.length; i++) {
      _voters.push(currGovernors[i]);
    }

    vm.startPrank(0x08295771719b138a241F45023B13CC868D72827D);
    TransparentUpgradeableProxy(payable(address(_newRoninBridgeManager))).changeAdmin(address(_currRoninBridgeManager));
    vm.stopPrank();

    _upgradeBridgeRoninchain();

    config.setAddress(network(), Contract.RoninBridgeManager.key(), address(_newRoninBridgeManager));
  }

  function _upgradeBridgeRoninchain() private {
    address bridgeRewardLogic = 0x8048b12511d9BE6e4e094089b12f54923C4E2F83;
    address bridgeSlashLogic = 0xfc274EC92bBb1A1472884558d1B5CaaC6F8220Ee;
    address bridgeTrackingLogic = 0x9521dBE27803f5d31da86d5846e7fE011d235018;
    address roninGatewayV3Logic = 0x5C530fe5920A2991eA6e9FB99028E1B09384D7f4;

    address bridgeRewardProxy = loadContract(Contract.BridgeReward.key());
    address bridgeSlashProxy = loadContract(Contract.BridgeSlash.key());
    address bridgeTrackingProxy = loadContract(Contract.BridgeTracking.key());
    address roninGatewayV3Proxy = loadContract(Contract.RoninGatewayV3.key());

    ISharedArgument.SharedParameter memory param;
    param.roninBridgeManager.callbackRegisters = new address[](1);
    param.roninBridgeManager.callbackRegisters[0] = loadContract(Contract.BridgeSlash.key());

    uint N = 16;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    uint cCount;

    targets[cCount] = bridgeRewardProxy;
    calldatas[cCount++] =
      abi.encodeWithSignature("upgradeToAndCall(address,bytes)", bridgeRewardLogic, abi.encodeWithSelector(BridgeReward.initializeV2.selector));

    targets[cCount] = bridgeSlashProxy;
    calldatas[cCount++] = abi.encodeWithSignature("upgradeTo(address)", bridgeSlashLogic);

    targets[cCount] = bridgeTrackingProxy;
    calldatas[cCount++] = abi.encodeWithSignature("upgradeTo(address)", bridgeTrackingLogic);

    targets[cCount] = roninGatewayV3Proxy;
    calldatas[cCount++] = abi.encodeWithSignature("upgradeTo(address)", roninGatewayV3Logic);

    targets[cCount] = bridgeRewardProxy;
    calldatas[cCount++] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newRoninBridgeManager))));

    targets[cCount] = bridgeSlashProxy;
    calldatas[cCount++] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newRoninBridgeManager))));

    targets[cCount] = bridgeTrackingProxy;
    calldatas[cCount++] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newRoninBridgeManager))));

    targets[cCount] = roninGatewayV3Proxy;
    calldatas[cCount++] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newRoninBridgeManager))));

    {
      address[] memory roninTokens = new address[](1);
      address[] memory mainchainTokens = new address[](1);
      uint256[] memory chainIds = new uint256[](1);
      TokenStandard[] memory standards = new TokenStandard[](1);

      roninTokens[0] = _wbtcRoninToken;
      mainchainTokens[0] = _wbtcMainchainToken;
      chainIds[0] = config.getNetworkData(config.getCompanionNetwork(network())).chainId;
      standards[0] = TokenStandard.ERC20;

      address[] memory mainchainTokensToSetMinThreshold = new address[](1);
      uint256[] memory minThresholds = new uint256[](1);
      mainchainTokensToSetMinThreshold[0] = _wbtcMainchainToken;
      minThresholds[0] = _wbtcMinThreshold;

      targets[cCount] = roninGatewayV3Proxy;
      calldatas[cCount++] =
        abi.encodeWithSignature("functionDelegateCall(bytes)", abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards)));

      targets[cCount] = roninGatewayV3Proxy;
      calldatas[cCount++] = abi.encodeWithSignature(
        "functionDelegateCall(bytes)", abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (mainchainTokensToSetMinThreshold, minThresholds))
      );
    }

    targets[cCount] = bridgeRewardProxy;
    calldatas[cCount++] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    targets[cCount] = bridgeSlashProxy;
    calldatas[cCount++] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    targets[cCount] = bridgeTrackingProxy;
    calldatas[cCount++] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    targets[cCount] = roninGatewayV3Proxy;
    calldatas[cCount++] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    targets[cCount] = address(_newRoninBridgeManager);
    calldatas[cCount++] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", (abi.encodeWithSignature("registerCallbacks(address[])", param.roninBridgeManager.callbackRegisters))
    );

    targets[cCount] = address(_newRoninBridgeManager);
    calldatas[cCount++] = abi.encodeWithSignature("changeAdmin(address)", address(_newRoninBridgeManager));

    assertEq(cCount, N);

    for (uint i; i < N; ++i) {
      gasAmounts[i] = 1_000_000;
    }

    _roninProposal.nonce = _currRoninBridgeManager.round(block.chainid) + 1;
    _roninProposal.chainId = block.chainid;
    _roninProposal.expiryTimestamp = 1723481999; // Wed Aug 12 2024 23:59:59 GMT+0700 (Indochina Time)
    _roninProposal.targets = targets;
    _roninProposal.values = values;
    _roninProposal.calldatas = calldatas;
    _roninProposal.gasAmounts = gasAmounts;

    _helperProposeForCurrentNetwork(_roninProposal);
  }

  function _postCheck() internal virtual override {
    console.log("Starting post-check".bold().cyan());
    _helperVoteForCurrentNetwork(_roninProposal);
    super._postCheck();
  }
}
