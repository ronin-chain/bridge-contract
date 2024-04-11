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
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { LibArray } from "./libraries/LibArray.sol";

contract Migration is BaseMigrationV2, Utils {
  ISharedArgument public constant config = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == Network.Sepolia.key()) {
      // tokens
      param.weth.name = "Wrapped WETH";
      param.weth.symbol = "WETH";
      param.axs.name = "Axie Infinity Shard";
      param.axs.symbol = "AXS";
      param.usdc.name = "USD Coin";
      param.usdc.symbol = "USDC";
      param.mockErc721.name = "Mock ERC721";
      param.mockErc721.symbol = "M_ERC721";

      uint256 num = 1;
      address[] memory operatorAddrs = new address[](num);
      address[] memory governorAddrs = new address[](num);
      uint256[] memory operatorPKs = new uint256[](num);
      uint256[] memory governorPKs = new uint256[](num);
      uint96[] memory voteWeights = new uint96[](num);
      GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](0);
      address[] memory targets = new address[](0);

      operatorAddrs[0] = 0xbA8E32D874948dF4Cbe72284De91CC4968293BCe; // One-time address, becomes useless after this migration
      operatorPKs[0] = 0xd5df10f17539ff887f211a90bfede2dffb664b7442b4303ba93ac8f6a7d9fa9b; // One-time address, becomes useless after this migration

      governorAddrs[0] = 0x45E8f1aCFC89F45720cf11e807eD85B730C67C7e; // One-time address, becomes useless after this migration
      governorPKs[0] = 0xc2b5a7cc553931272fc819150c4ea31d24ad06fdfa021c403b2ef5293bfe685b; // One-time address, becomes useless after this migration
      voteWeights[0] = 100;

      param.test.operatorPKs = operatorPKs;
      param.test.governorPKs = governorPKs;

      // Mainchain Gateway Pause Enforcer
      param.mainchainPauseEnforcer.admin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
      param.mainchainPauseEnforcer.sentries = wrapAddress(0x8Ed0c5B427688f2Bd945509199CAa4741C81aFFe); // Gnosis Sepolia

      // Mainchain Gateway V3
      param.mainchainGatewayV3.roleSetter = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
      param.mainchainGatewayV3.roninChainId = 2021;
      param.mainchainGatewayV3.numerator = 4 ;
      param.mainchainGatewayV3.highTierVWNumerator = 7;
      param.mainchainGatewayV3.denominator = 10;

      // Mainchain Bridge Manager
      param.mainchainBridgeManager.num = 2;
      param.mainchainBridgeManager.denom = 4;
      param.mainchainBridgeManager.roninChainId = 2021;
      param.mainchainBridgeManager.bridgeOperators = operatorAddrs;
      param.mainchainBridgeManager.governors = governorAddrs;
      param.mainchainBridgeManager.voteWeights = voteWeights;
      param.mainchainBridgeManager.targetOptions = options;
      param.mainchainBridgeManager.targets = targets;
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
      param.mockErc1155.uri = "mock://erc1155/";

      uint256 num = 22;
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
      param.roninGatewayV3.numerator = 7;
      param.roninGatewayV3.denominator = 10;
      param.roninGatewayV3.trustedNumerator = 9;
      param.roninGatewayV3.trustedDenominator = 10;

      // Ronin Bridge Manager
      param.roninBridgeManager.num = 7;
      param.roninBridgeManager.denom = 10;
      param.roninBridgeManager.roninChainId = block.chainid;
      param.roninBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
      param.roninBridgeManager.bridgeOperators = operatorAddrs;
      param.roninBridgeManager.governors = governorAddrs;
      param.roninBridgeManager.voteWeights = voteWeights;
      param.roninBridgeManager.targetOptions = options;
      param.roninBridgeManager.targets = targets;

      // Mainchain Gateway V3
      param.mainchainGatewayV3.roninChainId = block.chainid;
      param.mainchainGatewayV3.numerator = 7;
      param.mainchainGatewayV3.highTierVWNumerator = 9;
      param.mainchainGatewayV3.denominator = 10;

      // Mainchain Bridge Manager
      param.mainchainBridgeManager.num = 7;
      param.mainchainBridgeManager.denom = 10;
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
