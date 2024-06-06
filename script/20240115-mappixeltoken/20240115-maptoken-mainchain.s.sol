// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";

contract Migration__MapTokenMainchain is Migration {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;

  address constant _pixelRoninToken = address(0x8b50c162494567B3c8B7F00F6031341861c8dEeD);
  // TODO: fill this address
  address constant _pixelMainchainToken = address(0x0);

  // TODO: fill these thresholds
  uint256 constant _highTierThreshold = 0;
  uint256 constant _lockedThreshold = 0;
  // The MAX_PERCENTAGE is 1_000_000
  uint256 constant _unlockFeePercentages = 0;
  uint256 constant _dailyWithdrawalLimit = 0;

  address constant _farmlandRoninToken = address(0xF083289535052E8449D69e6dc41c0aE064d8e3f6);
  // TODO: fill this address
  address constant _farmlandMainchainToken = address(0x0);

  address constant _axieChatBridgeOperator = address(0x772112C7e5dD4ed663e844e79d77c1569a2E88ce);
  address constant _axieChatGovernor = address(0x5832C3219c1dA998e828E1a2406B73dbFC02a70C);

  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = config.getAddress(config.getCompanionNetwork(network()), Contract.MainchainGatewayV3.key());
    _mainchainBridgeManager = config.getAddress(config.getCompanionNetwork(network()), Contract.MainchainBridgeManager.key());
  }

  function _mapFarmlandToken() internal pure returns (bytes memory) {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);

    mainchainTokens[0] = _farmlandMainchainToken;
    roninTokens[0] = _farmlandRoninToken;
    standards[0] = TokenStandard.ERC721;

    // function mapTokens(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   TokenStandard[] calldata _standards
    // )

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokens, (mainchainTokens, roninTokens, standards));
    return abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);
  }

  function _mapPixelToken() internal pure returns (bytes memory) {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);
    uint256[][4] memory thresholds;

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

    mainchainTokens[0] = _farmlandMainchainToken;
    roninTokens[0] = _farmlandRoninToken;
    standards[0] = TokenStandard.ERC20;

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   TokenStandard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));
    return abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);
  }

  function _removeAxieChatGovernorAddress() internal pure returns (bytes memory) {
    address[] memory bridgeOperator = new address[](1);
    bridgeOperator[0] = _axieChatBridgeOperator;

    return abi.encodeCall(IBridgeManager.removeBridgeOperators, (bridgeOperator));
  }

  function _addAxieChatGovernorAddress() internal pure returns (bytes memory) {
    uint96[] memory voteWeight = new uint96[](1);
    address[] memory governor = new address[](1);
    address[] memory bridgeOperator = new address[](1);

    voteWeight[0] = 100;
    governor[0] = _axieChatGovernor;
    bridgeOperator[0] = _axieChatBridgeOperator;

    return abi.encodeCall(IBridgeManager.addBridgeOperators, (voteWeight, governor, bridgeOperator));
  }

  function run() public {
    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory calldatas = new bytes[](4);
    uint256[] memory gasAmounts = new uint256[](4);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = _mapFarmlandToken();
    gasAmounts[0] = 1_000_000;

    targets[1] = _mainchainGatewayV3;
    values[1] = 0;
    calldatas[1] = _mapPixelToken();
    gasAmounts[1] = 1_000_000;

    targets[2] = _mainchainBridgeManager;
    values[2] = 0;
    calldatas[2] = _removeAxieChatGovernorAddress();
    gasAmounts[2] = 1_000_000;

    targets[3] = _mainchainBridgeManager;
    values[3] = 0;
    calldatas[3] = _addAxieChatGovernorAddress();
    gasAmounts[3] = 1_000_000;

    (uint256 companionChainId, TNetwork companionNetwork) = network().companionNetworkData();
    address companionManager = config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
    LibProposal.verifyMainchainProposalGasAmount(companionNetwork, companionManager, targets, values, calldatas, gasAmounts);

    vm.broadcast(sender());
    _roninBridgeManager.propose(companionChainId, expiredTime, address(0), targets, values, calldatas, gasAmounts);
  }
}
