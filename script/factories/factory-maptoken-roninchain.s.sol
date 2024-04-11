// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";

import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

abstract contract Factory__MapTokensRoninchain is BridgeMigration {
  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;
  address private _governor;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    _governor = _initCaller();
    _cheatWeightOperator(_governor);
  }

  function _cheatWeightOperator(address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
  }

  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function run() public virtual {
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();

    address[] memory roninTokens = new address[](N);
    address[] memory mainchainTokens = new address[](N);
    uint256[] memory chainIds = new uint256[](N);
    TokenStandard[] memory standards = new TokenStandard[](N);

    uint256 expiredTime = block.timestamp + 14 days;
    address[] memory targets = new address[](2);
    uint256[] memory values = new uint256[](2);
    bytes[] memory calldatas = new bytes[](2);
    uint256[] memory gasAmounts = new uint256[](2);

    // ============= MAP TOKENS ===========

    for (uint256 i; i < N; ++i) {
      roninTokens[i] = tokenInfos[i].roninToken;
      mainchainTokens[i] = tokenInfos[i].mainchainToken;
      chainIds[i] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
      standards[i] = TokenStandard.ERC20;
    }

    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata _standards
    // )
    bytes memory innerData =
      abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
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
    address[] memory roninTokensToSetMinThreshold = new address[](N);
    uint256[] memory minThresholds = new uint256[](N);

    for (uint256 i; i < N; ++i) {
      roninTokensToSetMinThreshold[i] = tokenInfos[i].roninToken;
      minThresholds[i] = tokenInfos[i].minThreshold;
    }

    innerData =
      abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (roninTokensToSetMinThreshold, minThresholds));
    proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[1] = _roninGatewayV3;
    values[1] = 0;
    calldatas[1] = proxyData;
    gasAmounts[1] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    _verifyRoninProposalGasAmount(targets, values, calldatas, gasAmounts);

    vm.broadcast(_governor);
    _roninBridgeManager.propose(block.chainid, expiredTime, address(0), targets, values, calldatas, gasAmounts);
  }
}
