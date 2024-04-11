// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";

import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

import "forge-std/console2.sol";

import "./maptoken-pixel-configs.s.sol";
import "./update-axiechat-config.s.sol";

contract Migration__20240131_MapTokenPixelRoninchain is BridgeMigration, Migration__MapToken_Pixel_Config, Migration__Update_AxieChat_Config {
  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    _cheatWeightOperator(_governor);
  }

  function _cheatWeightOperator(address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
  }

  function run() public {
    address[] memory roninTokens = new address[](2);
    address[] memory mainchainTokens = new address[](2);
    uint256[] memory chainIds = new uint256[](2);
    TokenStandard[] memory standards = new TokenStandard[](2);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory calldatas = new bytes[](4);
    uint256[] memory gasAmounts = new uint256[](4);

    // ============= MAP PIXEL TOKEN AND FARMLAND ===========

    roninTokens[0] = _pixelRoninToken;
    mainchainTokens[0] = _pixelMainchainToken;
    chainIds[0] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
    standards[0] = TokenStandard.ERC20;

    roninTokens[1] = _farmlandRoninToken;
    mainchainTokens[1] = _farmlandMainchainToken;
    chainIds[1] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
    standards[1] = TokenStandard.ERC721;

    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata _standards
    // )
    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (
      roninTokens,
      mainchainTokens,
      chainIds,
      standards
    ));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ============= SET MIN THRESHOLD ============
    // function setMinimumThresholds(
    //   address[] calldata _tokens,
    //   uint256[] calldata _thresholds
    // );
    address[] memory mainchainTokensToSetMinThreshold = new address[](2);
    uint256[] memory minThresholds = new uint256[](2);

    mainchainTokensToSetMinThreshold[0] = _pixelMainchainToken;
    minThresholds[0] = _pixelMinThreshold;

    mainchainTokensToSetMinThreshold[1] = _aggMainchainToken;
    minThresholds[1] = _aggMinThreshold;

    innerData = abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (
      mainchainTokensToSetMinThreshold,
      minThresholds
    ));
    proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[1] = _roninGatewayV3;
    values[1] = 0;
    calldatas[1] = proxyData;
    gasAmounts[1] = 1_000_000;

    // =============== AXIE CHAT UPDATE ===========
    targets[2] = address(_roninBridgeManager);
    values[2] = 0;
    calldatas[2] = _removeAxieChatGovernorAddress();
    gasAmounts[2] = 1_000_000;

    targets[3] = address(_roninBridgeManager);
    values[3] = 0;
    calldatas[3] = _addAxieChatGovernorAddress();
    gasAmounts[3] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    _verifyRoninProposalGasAmount(targets, values, calldatas, gasAmounts);

    vm.broadcast(_governor);
    _roninBridgeManager.propose(
      block.chainid,
      expiredTime,
      targets,
      values,
      calldatas,
      gasAmounts
    );
  }
}
