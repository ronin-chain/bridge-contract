// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IGeneralConfigExtended } from "./IGeneralConfigExtended.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";

interface ISharedArgument is IGeneralConfigExtended {
  struct BridgeManagerParam {
    uint256 num;
    uint256 denom;
    uint256 roninChainId;
    uint256 expiryDuration;
    address bridgeContract;
    address[] callbackRegisters;
    address[] bridgeOperators;
    address[] governors;
    uint96[] voteWeights;
    GlobalProposal.TargetOption[] targetOptions;
    address[] targets;
    uint256 minRequiredGovernor;
  }

  struct MainchainGatewayV3Param {
    address roleSetter;
    address wrappedToken;
    uint256 roninChainId;
    uint256 numerator;
    uint256 highTierVWNumerator;
    uint256 denominator;
    // addresses[0]: mainchainTokens
    // addresses[1]: roninTokens
    // addresses[2]: withdrawalUnlockers
    address[][3] addresses;
    // thresholds[0]: highTierThreshold
    // thresholds[1]: lockedThreshold
    // thresholds[2]: unlockFeePercentages
    // thresholds[3]: dailyWithdrawalLimit
    uint256[][4] thresholds;
    TokenStandard[] standards;
  }

  struct RoninGatewayV3Param {
    address roleSetter;
    uint256 numerator;
    uint256 denominator;
    uint256 trustedNumerator;
    uint256 trustedDenominator;
    address[] withdrawalMigrators;
    // packedAddresses[0]: roninTokens
    // packedAddresses[1]: mainchainTokens
    address[][2] packedAddresses;
    // packedNumbers[0]: chainIds
    // packedNumbers[1]: minimumThresholds
    uint256[][2] packedNumbers;
    TokenStandard[] standards;
  }

  struct BridgeSlashParam {
    address validatorContract;
    address bridgeManagerContract;
    address bridgeTrackingContract;
    address dposGA;
  }

  struct BridgeTrackingParam {
    address bridgeContract;
    address validatorContract;
    uint256 startedAtBlock;
  }

  struct BridgeRewardParam {
    address bridgeManagerContract;
    address bridgeTrackingContract;
    address bridgeSlashContract;
    address validatorSetContract;
    address dposGA;
    uint256 rewardPerPeriod;
  }

  struct PauseEnforcerParam {
    address target;
    address admin;
    address[] sentries;
  }

  struct MockWrappedTokenParam {
    string name;
    string symbol;
  }

  struct MockERC20Param {
    string name;
    string symbol;
  }

  struct MockERC721Param {
    string name;
    string symbol;
  }

  struct MockERC1155Param {
    string uri;
  }

   struct RoninMockERC1155Param {
    address defaultAdmin;
     string uri; 
     string  name; 
     string  symbol;
  }

  struct UnitTestParam {
    address proxyAdmin;
    uint256 numberOfBlocksInEpoch;
    address dposGA;
    uint256[] operatorPKs;
    uint256[] governorPKs;
  }

  struct WethUnwrapperParam {
    address weth;
    address owner;
  }

  struct SharedParameter {
    // mainchain
    BridgeManagerParam mainchainBridgeManager;
    MainchainGatewayV3Param mainchainGatewayV3;
    PauseEnforcerParam mainchainPauseEnforcer;
    WethUnwrapperParam mainchainWethUnwrapper;
    // ronin
    BridgeManagerParam roninBridgeManager;
    RoninGatewayV3Param roninGatewayV3;
    PauseEnforcerParam roninPauseEnforcer;
    BridgeSlashParam bridgeSlash;
    BridgeTrackingParam bridgeTracking;
    BridgeRewardParam bridgeReward;
    // tokens
    MockWrappedTokenParam weth;
    MockWrappedTokenParam wron;
    MockERC20Param axs;
    MockERC20Param slp;
    MockERC20Param usdc;
    MockERC721Param mockErc721;
    MockERC1155Param mockErc1155;
    RoninMockERC1155Param roninMockErc1155;
    UnitTestParam test;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
