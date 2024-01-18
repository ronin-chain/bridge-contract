// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { GeneralConfig } from "./GeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { Network } from "./utils/Network.sol";
import { Utils } from "./utils/Utils.sol";
import { Contract } from "./utils/Contract.sol";

import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";

contract Migration is BaseMigration, Utils {
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
      uint256 num = 6;
      address[] memory operatorAddrs = new address[](num);
      address[] memory governorAddrs = new address[](num);
      uint256[] memory operatorPKs = new uint256[](num);
      uint256[] memory governorPKs = new uint256[](num);
      uint96[] memory voteWeights = new uint96[](num);
      for (uint256 i; i < num; i++) {
        (address addrOperator, uint256 pkOperator) = makeAddrAndKey(string.concat("operator-", vm.toString(i + 1)));
        (address addrGovernor, uint256 pkGovernor) = makeAddrAndKey(string.concat("governor-", vm.toString(i + 1)));
        operatorAddrs[i] = addrOperator;
        governorAddrs[i] = addrGovernor;
        operatorPKs[i] = pkOperator;
        governorPKs[i] = pkGovernor;
        voteWeights[i] = 100;
      }

      address governanceAdmin = makeAddr("governance-admin");
      address validatorSetContract = makeAddr("validator-set-contract");
      Token.Standard[] memory standards = new Token.Standard[](1);
      standards[0] = Token.Standard.ERC20;

      GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](4);
      address[] memory targets = new address[](4);

      options[0] = GlobalProposal.TargetOption.GatewayContract;
      targets[0] = loadContract(Contract.RoninGatewayV3.key());

      options[1] = GlobalProposal.TargetOption.BridgeReward;
      targets[1] = loadContract(Contract.BridgeReward.key());

      options[2] = GlobalProposal.TargetOption.BridgeSlash;
      targets[2] = loadContract(Contract.BridgeSlash.key());

      options[3] = GlobalProposal.TargetOption.BridgeTracking;
      targets[3] = loadContract(Contract.BridgeTracking.key());

      // test
      param.test.proxyAdmin = makeAddr("proxy-admin");
      param.test.operatorPKs = operatorPKs;
      param.test.governorPKs = governorPKs;

      // Bridge rewards
      param.bridgeReward.bridgeManagerContract = loadContract(Contract.RoninBridgeManager.key());
      param.bridgeReward.bridgeTrackingContract = loadContract(Contract.BridgeTracking.key());
      param.bridgeReward.bridgeSlashContract = loadContract(Contract.BridgeSlash.key());
      param.bridgeReward.validatorSetContract = validatorSetContract;
      param.bridgeReward.dposGA = governanceAdmin;
      param.bridgeReward.rewardPerPeriod = 5_000;

      // Bridge Slash
      param.bridgeSlash.validatorContract = validatorSetContract;
      param.bridgeSlash.bridgeManagerContract = loadContract(Contract.RoninBridgeManager.key());
      param.bridgeSlash.bridgeTrackingContract = loadContract(Contract.BridgeTracking.key());
      param.bridgeSlash.dposGA = governanceAdmin;

      // Bridge Tracking
      param.bridgeTracking.bridgeContract = loadContract(Contract.RoninGatewayV3.key());
      param.bridgeTracking.validatorContract = validatorSetContract;

      // Ronin Bridge Manager
      param.roninBridgeManager.num = 2;
      param.roninBridgeManager.denom = 4;
      param.roninBridgeManager.roninChainId = 0;
      param.roninBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
      param.roninBridgeManager.bridgeContract = loadContract(Contract.RoninGatewayV3.key());
      param.roninBridgeManager.callbackRegisters = wrapAddress(loadContract(Contract.BridgeSlash.key()));
      param.roninBridgeManager.bridgeOperators = operatorAddrs;
      param.roninBridgeManager.governors = governorAddrs;
      param.roninBridgeManager.voteWeights = voteWeights;
      param.roninBridgeManager.targetOptions = options;
      param.roninBridgeManager.targets = targets;

      // Ronin Gateway V3
      param.roninGatewayV3.roleSetter = address(0);
      param.roninGatewayV3.numerator = 3;
      param.roninGatewayV3.denominator = 6;
      param.roninGatewayV3.trustedNumerator = 2;
      param.roninGatewayV3.trustedDenominator = 3;
      param.roninGatewayV3.withdrawalMigrators = getEmptyAddressArray();
      param.roninGatewayV3.packedAddresses[0] = wrapAddress(address(0));
      param.roninGatewayV3.packedAddresses[1] = wrapAddress(address(0));
      param.roninGatewayV3.packedNumbers[0] = wrapUint(1);
      param.roninGatewayV3.packedNumbers[1] = wrapUint(0);
      param.roninGatewayV3.standards = standards;

      // Mainchain Bridge Manager
      delete options;
      delete targets;

      options = new GlobalProposal.TargetOption[](1);
      targets = new address[](1);

      options[0] = GlobalProposal.TargetOption.GatewayContract;
      targets[0] = loadContract(Contract.MainchainGatewayV3.key());

      param.mainchainBridgeManager.num = 2;
      param.mainchainBridgeManager.denom = 4;
      param.mainchainBridgeManager.roninChainId = 0;
      param.mainchainBridgeManager.bridgeContract = loadContract(Contract.MainchainGatewayV3.key());
      param.mainchainBridgeManager.callbackRegisters = getEmptyAddressArray();
      param.mainchainBridgeManager.bridgeOperators = operatorAddrs;
      param.mainchainBridgeManager.governors = governorAddrs;
      param.mainchainBridgeManager.voteWeights = voteWeights;
      param.mainchainBridgeManager.targetOptions = options;
      param.mainchainBridgeManager.targets = targets;

      // Mainchain Gateway V3
      delete standards;
      standards = new Token.Standard[](2);

      standards[0] = Token.Standard.ERC20;
      standards[1] = Token.Standard.ERC20;

      param.mainchainGatewayV3.roleSetter = address(0);
      param.mainchainGatewayV3.roninChainId = 0;
      param.mainchainGatewayV3.numerator = 1;
      param.mainchainGatewayV3.highTierVWNumerator = 10;
      param.mainchainGatewayV3.denominator = 10;
      param.mainchainGatewayV3.addresses[0] =
        wrapAddress(loadContract(Contract.WETH.key()), loadContract(Contract.USDC.key())); // mainchain tokens
      param.mainchainGatewayV3.addresses[1] =
        wrapAddress(loadContract(Contract.WETH.key()), loadContract(Contract.USDC.key())); // ronin tokens
      param.mainchainGatewayV3.addresses[2] = getEmptyAddressArray(); //withdrawalUnlockers
      param.mainchainGatewayV3.thresholds[0] = wrapUint(10, 0); // highTierThreshold
      param.mainchainGatewayV3.thresholds[1] = wrapUint(20, 0); // lockedThreshold
      param.mainchainGatewayV3.thresholds[2] = wrapUint(100_000, 0); // unlockFeePercentages
      param.mainchainGatewayV3.thresholds[3] = wrapUint(12, 0); // dailyWithdrawalLimits
      param.mainchainGatewayV3.standards = standards;

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
    } else {
      revert("Migration: Network Unknown Shared Parameters Unimplemented!");
    }

    rawArgs = abi.encode(param);
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    return network() == DefaultNetwork.Local.key()
      ? payable(config.sharedArguments().test.proxyAdmin)
      : super._getProxyAdmin();
  }
}
