// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseMigrationV2 } from "./BaseMigrationV2.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { GeneralConfig } from "./GeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { Network } from "./utils/Network.sol";
import { Utils } from "./utils/Utils.sol";
import { Contract } from "./utils/Contract.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { LibArray } from "./libraries/LibArray.sol";

contract Migration is BaseMigrationV2, Utils {
  ISharedArgument public constant config = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == Network.Goerli.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.RoninTestnet.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.Local.key()) {
      // test
      param.test.numberOfBlocksInEpoch = 200;
      param.test.proxyAdmin = makeAddr("proxy-admin");
      param.test.dposGA = makeAddr("governance-admin");

      // tokens
      param.weth.name = "Wrapped WETH";
      param.weth.symbol = "WETH";
      param.wron.name = "Wrapped RON";
      param.wron.symbol = "WRON";
      param.axs.name = "Axie Infinity Shard";
      param.axs.symbol = "AXS";
      param.slp.name = "Smooth Love Potion";
      param.slp.symbol = "SLP";
      param.usdc.name = "USD Coin";
      param.usdc.symbol = "USDC";
      param.mockErc721.name = "Mock ERC721";
      param.mockErc721.symbol = "M_ERC721";

      uint256 num = 6;
      address[] memory operatorAddrs = new address[](num);
      address[] memory governorAddrs = new address[](num);
      uint256[] memory operatorPKs = new uint256[](num);
      uint256[] memory governorPKs = new uint256[](num);
      uint96[] memory voteWeights = new uint96[](num);
      GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](0);
      address[] memory targets = new address[](0);

      for (uint256 i; i < num; i++) {
        (address addrOperator, uint256 pkOperator) = makeAddrAndKey(string.concat("operator-", vm.toString(i + 1)));
        (address addrGovernor, uint256 pkGovernor) = makeAddrAndKey(string.concat("governor-", vm.toString(i + 1)));

        operatorAddrs[i] = addrOperator;
        governorAddrs[i] = addrGovernor;
        operatorPKs[i] = pkOperator;
        governorPKs[i] = pkGovernor;
        voteWeights[i] = 100;
      }

      LibArray.inlineSortByValue(operatorPKs, LibArray.toUint256s(operatorAddrs));
      LibArray.inlineSortByValue(governorPKs, LibArray.toUint256s(governorAddrs));

      param.test.operatorPKs = operatorPKs;
      param.test.governorPKs = governorPKs;

      // Bridge rewards
      param.bridgeReward.dposGA = param.test.dposGA;
      param.bridgeReward.rewardPerPeriod = 5_000;

      // Bridge Slash
      param.bridgeSlash.dposGA = param.test.dposGA;

      // Bridge Tracking

      // Ronin Gateway Pause Enforcer
      param.roninPauseEnforcer.admin = makeAddr("pause-enforcer-admin");
      param.roninPauseEnforcer.sentries = wrapAddress(makeAddr("pause-enforcer-sentry"));

      // Ronin Gateway V3
      param.roninGatewayV3.numerator = 3;
      param.roninGatewayV3.denominator = 6;
      param.roninGatewayV3.trustedNumerator = 2;
      param.roninGatewayV3.trustedDenominator = 3;

      // Ronin Bridge Manager
      param.roninBridgeManager.num = 2;
      param.roninBridgeManager.denom = 4;
      param.roninBridgeManager.roninChainId = 0;
      param.roninBridgeManager.roninChainId = block.chainid;
      param.roninBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
      param.roninBridgeManager.bridgeOperators = operatorAddrs;
      param.roninBridgeManager.governors = governorAddrs;
      param.roninBridgeManager.voteWeights = voteWeights;
      param.roninBridgeManager.targetOptions = options;
      param.roninBridgeManager.targets = targets;

      // Mainchain Gateway Pause Enforcer
      param.mainchainPauseEnforcer.admin = makeAddr("pause-enforcer-admin");
      param.mainchainPauseEnforcer.sentries = wrapAddress(makeAddr("pause-enforcer-sentry"));

      // Mainchain Gateway V3
      param.mainchainGatewayV3.roninChainId = block.chainid;
      param.mainchainGatewayV3.numerator = 1;
      param.mainchainGatewayV3.highTierVWNumerator = 10;
      param.mainchainGatewayV3.denominator = 10;

      // Mainchain Bridge Manager
      param.mainchainBridgeManager.num = 2;
      param.mainchainBridgeManager.denom = 4;
      param.mainchainBridgeManager.roninChainId = 0;
      param.mainchainBridgeManager.roninChainId = block.chainid;
      param.mainchainBridgeManager.bridgeOperators = operatorAddrs;
      param.mainchainBridgeManager.governors = governorAddrs;
      param.mainchainBridgeManager.voteWeights = voteWeights;
      param.mainchainBridgeManager.targetOptions = options;
      param.mainchainBridgeManager.targets = targets;
    } else {
      revert("Migration: Network Unknown Shared Parameters Unimplemented!");
    }

    rawArgs = abi.encode(param);
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    bool isLocalNetwork = network() == DefaultNetwork.Local.key();
    return isLocalNetwork ? payable(config.sharedArguments().test.proxyAdmin) : super._getProxyAdmin();
  }
}
