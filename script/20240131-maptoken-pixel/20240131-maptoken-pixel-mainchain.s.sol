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

import "./maptoken-pixel-configs.s.sol";
import "./update-axiechat-config.s.sol";

contract Migration__20240131_MapTokenPixelMainchain is BridgeMigration, Migration__MapToken_Pixel_Config, Migration__Update_AxieChat_Config {
  RoninBridgeManager internal _roninBridgeManager;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = _config.getAddress(
      _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).key(),
      Contract.MainchainGatewayV3.key()
    );
    _mainchainBridgeManager = _config.getAddress(
      _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).key(),
      Contract.MainchainBridgeManager.key()
    );
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    Token.Standard[] memory standards = new Token.Standard[](1);
    uint256[][4] memory thresholds;

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory calldatas = new bytes[](4);
    uint256[] memory gasAmounts = new uint256[](4);

    // ================ PIXEL ERC-20 ======================

    mainchainTokens[0] = _pixelMainchainToken;
    roninTokens[0] = _pixelRoninToken;
    standards[0] = Token.Standard.ERC20;
    // highTierThreshold
    thresholds[0] = new uint256[](1);
    thresholds[0][0] = _highTierThreshold;
    // lockedThreshold
    thresholds[1] = new uint256[](1);
    thresholds[1][0] = _lockedThreshold;
    // unlockFeePercentages
    thresholds[2] = new uint256[](1);
    thresholds[2][0] = _unlockFeePercentages;
    // dailyWithdrawalLimit
    thresholds[3] = new uint256[](1);
    thresholds[3][0] = _dailyWithdrawalLimit;

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   Token.Standard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (
      mainchainTokens,
      roninTokens,
      standards,
      thresholds
    ));

    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ FARMLAND ERC-20 ======================

    mainchainTokens[0] = _farmlandMainchainToken;
    roninTokens[0] = _farmlandRoninToken;
    standards[0] = Token.Standard.ERC721;

    // function mapTokens(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   Token.Standard[] calldata _standards
    // ) external;

    innerData = abi.encodeCall(IMainchainGatewayV3.mapTokens, (
      mainchainTokens,
      roninTokens,
      standards
    ));

    proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[1] = _mainchainGatewayV3;
    values[1] = 0;
    calldatas[1] = proxyData;
    gasAmounts[1] = 1_000_000;

    // =============== AXIE CHAT UPDATE ===========
    targets[2] = _mainchainBridgeManager;
    values[2] = 0;
    calldatas[2] = _addAxieChatGovernorAddress();
    gasAmounts[2] = 1_000_000;

    targets[3] = _mainchainBridgeManager;
    values[3] = 0;
    calldatas[3] = _removeAxieChatGovernorAddress();
    gasAmounts[3] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    _verifyMainchainProposalGasAmount(targets, values, calldatas, gasAmounts);

    uint256 chainId = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();

    vm.broadcast(_governor);
    _roninBridgeManager.propose(
      chainId,
      expiredTime,
      targets,
      values,
      calldatas,
      gasAmounts
    );
  }
}
