// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";

import { TNetwork } from "@fdk/types/TNetwork.sol";

import { Migration } from "script/Migration.s.sol";
import { MapTokenInfo } from "script/libraries/MapTokenInfo.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { AXSDeploy } from "script/contracts/token/AXSDeploy.s.sol";

abstract contract MapTokenConfig is Migration {
  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 30 minutes;

  MapTokenInfo internal _axs = MapTokenInfo({
    roninToken: 0x3C4e17b9056272Ce1b49F6900d8cFD6171a1869d,
    mainchainToken: 0x5999Df8EC820A7d40C5D0606E7cbE17cfC890592,
    minThreshold: 20000000,
    highTierThreshold: 90000000000000000000,
    lockedThreshold: 40000000000000000000,
    dailyWithdrawalLimit: 100000000000000000000,
    unlockFeePercentages: 100000, // Max percentage is: 1_000_000
    standard: TokenStandard.ERC20
  });

  MapTokenInfo[] internal _mapTokens;

  function run() public virtual {
    // Deploy on Sepolia
    TNetwork companionNetwork = config.getCompanionNetwork(network());
    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(companionNetwork, 7801960);
    address newAxs = address(new AXSDeploy().run());

    address mainchainGw = config.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());
    uint256 prvAxsBalance = IERC20(_axs.mainchainToken).balanceOf(mainchainGw);
    require(prvAxsBalance > 0, "AXS balance is 0");
    vm.broadcast(sender());
    MockERC20(newAxs).mint(mainchainGw, prvAxsBalance);

    switchBack(prvNetwork, prvForkId);
    // Update new axs
    _axs.mainchainToken = newAxs;

    _mapTokens.push(_axs);
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
