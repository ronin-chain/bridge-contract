// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

abstract contract Factory__MapTokensMainchain is BridgeMigration {
  RoninBridgeManager internal _roninBridgeManager;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;
  address private _governor;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = _config.getAddress(
      _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).key(), Contract.MainchainGatewayV3.key()
    );
    _mainchainBridgeManager = _config.getAddress(
      _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).key(),
      Contract.MainchainBridgeManager.key()
    );

    _governor = _initCaller();
  }

  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function run() public virtual {
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();

    address[] memory mainchainTokens = new address[](N);
    address[] memory roninTokens = new address[](N);
    Token.Standard[] memory standards = new Token.Standard[](N);
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
      standards[i] = Token.Standard.ERC20;
      thresholds[0][i] = tokenInfos[i].highTierThreshold;
      thresholds[1][i] = tokenInfos[i].lockedThreshold;
      thresholds[2][i] = tokenInfos[i].unlockFeePercentages;
      thresholds[3][i] = tokenInfos[i].dailyWithdrawalLimit;
    }

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   Token.Standard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    bytes memory innerData =
      abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));

    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    _verifyMainchainProposalGasAmount(targets, values, calldatas, gasAmounts);

    uint256 chainId = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();

    vm.broadcast(_governor);
    _roninBridgeManager.propose(chainId, expiredTime, targets, values, calldatas, gasAmounts);
  }
}
