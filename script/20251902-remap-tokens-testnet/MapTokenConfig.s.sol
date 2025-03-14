// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";

import { Migration } from "script/Migration.s.sol";
import { MapTokenInfo } from "script/libraries/MapTokenInfo.sol";
import { TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

abstract contract MapTokenConfig is Migration {
  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 30 minutes;

  MapTokenInfo internal _usdc = MapTokenInfo({
    roninToken: 0x067FBFf8990c58Ab90BaE3c97241C5d736053F77,
    mainchainToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // previously: 0x1C27983FBf738494F167A1eD31F2974ad45d28e4
    minThreshold: 20000000,
    highTierThreshold: 900000000,
    lockedThreshold: 400000000,
    dailyWithdrawalLimit: 1000000000,
    unlockFeePercentages: 10, // Max percentage is: 1_000_000
    standard: TokenStandard.ERC20
  });

  MapTokenInfo[] internal _mapTokens;

  function run() public virtual {
    _mapTokens.push(_usdc);
  }

  function getMainchainMapData() public view returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) {
    targets = new address[](1);
    values = new uint256[](1);
    callDatas = new bytes[](1);
    gasAmounts = new uint256[](1);

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   TokenStandard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )
    uint256 tokenCount = _mapTokens.length;
    address[] memory roninTokens = new address[](tokenCount);
    address[] memory mainchainTokens = new address[](tokenCount);
    TokenStandard[] memory standards = new TokenStandard[](tokenCount);
    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](tokenCount);
    thresholds[1] = new uint256[](tokenCount);
    thresholds[2] = new uint256[](tokenCount);
    thresholds[3] = new uint256[](tokenCount);

    for (uint256 i; i < tokenCount; i++) {
      roninTokens[i] = _mapTokens[i].roninToken;
      mainchainTokens[i] = _mapTokens[i].mainchainToken;
      standards[i] = _mapTokens[i].standard;

      thresholds[0][i] = _mapTokens[i].highTierThreshold;
      thresholds[1][i] = _mapTokens[i].lockedThreshold;
      thresholds[2][i] = _mapTokens[i].unlockFeePercentages;
      thresholds[3][i] = _mapTokens[i].dailyWithdrawalLimit;
    }

    targets[0] = vme.getAddress(config.getCompanionNetwork(network()), Contract.MainchainGatewayV3.key());
    values[0] = 0;
    callDatas[0] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)",
      abi.encodeWithSignature("mapTokensAndThresholds(address[],address[],uint8[],uint256[][4])", mainchainTokens, roninTokens, standards, thresholds)
    );
    gasAmounts[0] = 4_000_000;
  }

  function getRoninMapData() public view returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) {
    targets = new address[](2);
    values = new uint256[](2);
    callDatas = new bytes[](2);
    gasAmounts = new uint256[](2);

    // function mapTokens(
    //   address[] calldata roninTokens,
    //   address[] calldata mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata standards
    // )
    uint256 tokenCount = _mapTokens.length;
    address[] memory roninTokens = new address[](tokenCount);
    address[] memory mainchainTokens = new address[](tokenCount);
    uint256[] memory chainIds = new uint256[](tokenCount);
    TokenStandard[] memory standards = new TokenStandard[](tokenCount);

    uint256 companionChainId = config.getNetworkData(config.getCompanionNetwork(network())).chainId;
    for (uint256 i; i < tokenCount; i++) {
      roninTokens[i] = _mapTokens[i].roninToken;
      mainchainTokens[i] = _mapTokens[i].mainchainToken;
      chainIds[i] = companionChainId;
      standards[i] = _mapTokens[i].standard;
    }

    targets[0] = loadContract(Contract.RoninGatewayV3.key());
    values[0] = 0;
    callDatas[0] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)",
      abi.encodeWithSignature("mapTokens(address[],address[],uint256[],uint8[])", roninTokens, mainchainTokens, chainIds, standards)
    );
    gasAmounts[0] = 4_000_000;

    // function setMinimumThresholds(
    //   address[] calldata tokens,
    //   uint256[] calldata thresholds
    // );
    roninTokens = new address[](tokenCount);
    uint256[] memory thresholds = new uint256[](tokenCount);
    uint256 j;

    for (uint256 i; i < tokenCount; i++) {
      if (_mapTokens[i].standard == TokenStandard.ERC721) {
        continue;
      }

      roninTokens[j] = _mapTokens[i].roninToken;
      thresholds[j] = _mapTokens[i].minThreshold;
      j++;
    }
    targets[1] = loadContract(Contract.RoninGatewayV3.key());
    values[1] = 0;
    gasAmounts[1] = 1_000_000;
    callDatas[1] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", abi.encodeWithSignature("setMinimumThresholds(address[],uint256[])", roninTokens, thresholds));
  }
}
