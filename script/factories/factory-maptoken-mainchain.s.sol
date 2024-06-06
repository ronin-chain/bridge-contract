// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../interfaces/IGeneralConfigExtended.sol";

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

abstract contract Factory__MapTokensMainchain is Migration {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;
  address private _governor;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = config.getAddress(network().companionNetwork(), Contract.MainchainGatewayV3.key());
    _mainchainBridgeManager = config.getAddress(network().companionNetwork(), Contract.MainchainBridgeManager.key());

    _governor = _initCaller();
  }

  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function run() public virtual {
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();

    address[] memory mainchainTokens = new address[](N);
    address[] memory roninTokens = new address[](N);
    TokenStandard[] memory standards = new TokenStandard[](N);
    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](N);
    thresholds[1] = new uint256[](N);
    thresholds[2] = new uint256[](N);
    thresholds[3] = new uint256[](N);

    uint256 expiredTime = block.timestamp + 14 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    // ================ APERIOS AND YGG ERC-20 ======================

    for (uint256 i; i < N; ++i) {
      mainchainTokens[i] = tokenInfos[i].mainchainToken;
      roninTokens[i] = tokenInfos[i].roninToken;
      standards[i] = TokenStandard.ERC20;
      thresholds[0][i] = tokenInfos[i].highTierThreshold;
      thresholds[1][i] = tokenInfos[i].lockedThreshold;
      thresholds[2][i] = tokenInfos[i].unlockFeePercentages;
      thresholds[3][i] = tokenInfos[i].dailyWithdrawalLimit;
    }

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   TokenStandard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));

    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    // _verifyMainchainProposalGasAmount(targets, values, calldatas, gasAmounts);

    uint256 chainId = network().companionChainId();

    vm.broadcast(_governor);
    _roninBridgeManager.propose(chainId, expiredTime, address(0), targets, values, calldatas, gasAmounts);
  }
}
