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

contract Migration__20231215_MapTokenMainchain is BridgeMigration {
  RoninBridgeManager internal _roninBridgeManager;
  address constant _aggRoninToken = address(0x294311a8C37F0744F99EB152c419D4D3D6FEC1C7);
  address constant _aggMainchainToken = address(0xFB0489e9753B045DdB35e39c6B0Cc02EC6b99AC5);
  address internal _mainchainGatewayV3;

  // The decimal of AGG token is 18
  uint256 constant _highTierThreshold = 200_000_000 ether;
  uint256 constant _lockedThreshold = 800_000_000 ether;
  // The MAX_PERCENTAGE is 1_000_000
  uint256 constant _unlockFeePercentages = 10;
  uint256 constant _dailyWithdrawalLimit = 500_000_000 ether;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = _config.getAddress(
      _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).key(), Contract.MainchainGatewayV3.key()
    );
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    mainchainTokens[0] = _aggMainchainToken;
    address[] memory roninTokens = new address[](1);
    roninTokens[0] = _aggRoninToken;
    Token.Standard[] memory standards = new Token.Standard[](1);
    standards[0] = Token.Standard.ERC20;
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

    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   Token.Standard[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    bytes memory innerData =
      abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    targets[0] = _mainchainGatewayV3;
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = proxyData;
    uint256[] memory gasAmounts = new uint256[](1);
    gasAmounts[0] = 1_000_000;

    _verifyMainchainProposalGasAmount(targets, values, calldatas, gasAmounts);

    uint256 chainId = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();

    vm.broadcast(sender());
    _roninBridgeManager.propose(chainId, expiredTime, targets, values, calldatas, gasAmounts);
  }
}
