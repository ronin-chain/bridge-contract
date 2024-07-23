// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ronin/contracts/libraries/Ballot.sol";
import { console2 as console } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../../utils/Contract.sol";
import { Migration } from "../../Migration.s.sol";
import { Network, TNetwork } from "../../utils/Network.sol";
import { IGeneralConfigExtended } from "../../interfaces/IGeneralConfigExtended.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { MapTokenInfo } from "../../libraries/MapTokenInfo.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Network, TNetwork } from "../../utils/Network.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

abstract contract Factory__MapTokensMainchain is Migration {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;
  address internal _specifiedCaller;
  address[] internal _governors;
  uint256[] internal _governorPKs;

  function setUp() public virtual override {
    super.setUp();
    _specifiedCaller = _initCaller();
  }

  function run() public virtual;
  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function _propose(Proposal.ProposalDetail memory proposal) internal virtual {
    vm.broadcast(_specifiedCaller);
    _roninBridgeManager.propose(
      proposal.chainId, proposal.expiryTimestamp, proposal.executor, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts
    );
  }

  function _relayProposal(Proposal.ProposalDetail memory proposal) internal {
    MainchainBridgeAdminUtils mainchainProposalUtils =
      new MainchainBridgeAdminUtils(2021, _governorPKs, MainchainBridgeManager(_mainchainBridgeManager), _governors[0]);

    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](_governors.length);
    require(_governors.length > 0 && _governors.length == _governorPKs.length, "Invalid governors information");

    for (uint256 i; i < _governors.length; ++i) {
      supports_[i] = Ballot.VoteType.For;
    }

    SignatureConsumer.Signature[] memory signatures = mainchainProposalUtils.generateSignatures(proposal, _governorPKs);

    uint256 gasAmounts = 1_000_000;
    for (uint256 i; i < proposal.gasAmounts.length; ++i) {
      gasAmounts += proposal.gasAmounts[i];
    }

    vm.broadcast(_governors[0]);
    MainchainBridgeManager(_mainchainBridgeManager).relayProposal{ gas: gasAmounts }(proposal, supports_, signatures);
  }

  function _createAndVerifyProposalOnMainchain(uint256 chainId, uint256 nonce) internal returns (Proposal.ProposalDetail memory proposal) {
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();
    require(tokenInfos.length > 0, "Number of tokens required to map cannot be 0.");

    bytes memory innerData;
    bytes memory proxyData;

    if (tokenInfos[0].standard == TokenStandard.ERC20) {
      (address[] memory mainchainTokens, address[] memory roninTokens, TokenStandard[] memory standards, uint256[][4] memory thresholds) =
        _prepareMapTokensAndThresholds(N, tokenInfos);

      innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));
      proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);
    } else {
      (address[] memory mainchainTokens, address[] memory roninTokens, TokenStandard[] memory standards) = _prepareMapTokens(N, tokenInfos);

      innerData = abi.encodeCall(IMainchainGatewayV3.mapTokens, (mainchainTokens, roninTokens, standards));
      proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);
    }

    uint256 expiredTime = block.timestamp + 14 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    if (block.chainid == 2020) {
      // Verify gas when call from ronin.
      (uint256 companionChainId, TNetwork companionNetwork) = network().companionNetworkData();
      address companionManager = config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
      LibProposal.verifyMainchainProposalGasAmount(companionNetwork, companionManager, targets, values, calldatas, gasAmounts);
    } else {
      // Verify gas when call from mainchain.
      LibProposal.verifyProposalGasAmount(address(_mainchainBridgeManager), targets, values, calldatas, gasAmounts);
    }

    proposal = Proposal.ProposalDetail({
      nonce: nonce,
      chainId: chainId,
      expiryTimestamp: expiredTime,
      executor: address(0),
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
  }

  function _prepareMapTokensAndThresholds(
    uint256 N,
    MapTokenInfo[] memory tokenInfos
  ) internal returns (address[] memory mainchainTokens, address[] memory roninTokens, TokenStandard[] memory standards, uint256[][4] memory thresholds) {
    // function mapTokensAndThresholds(
    //   address[] calldata _mainchainTokens,
    //   address[] calldata _roninTokens,
    //   TokenStandard.ERC20[] calldata _standards,
    //   uint256[][4] calldata _thresholds
    // )

    mainchainTokens = new address[](N);
    roninTokens = new address[](N);
    standards = new TokenStandard[](N);

    thresholds[0] = new uint256[](N);
    thresholds[1] = new uint256[](N);
    thresholds[2] = new uint256[](N);
    thresholds[3] = new uint256[](N);

    for (uint256 i; i < N; ++i) {
      mainchainTokens[i] = tokenInfos[i].mainchainToken;
      roninTokens[i] = tokenInfos[i].roninToken;
      standards[i] = tokenInfos[i].standard;

      thresholds[0][i] = tokenInfos[i].highTierThreshold;
      thresholds[1][i] = tokenInfos[i].lockedThreshold;
      thresholds[2][i] = tokenInfos[i].unlockFeePercentages;
      thresholds[3][i] = tokenInfos[i].dailyWithdrawalLimit;
    }
  }

  function _prepareMapTokens(
    uint256 N,
    MapTokenInfo[] memory tokenInfos
  ) internal returns (address[] memory mainchainTokens, address[] memory roninTokens, TokenStandard[] memory standards) {
    //  function mapTokens(
    //    address[] calldata _mainchainTokens,
    //    address[] calldata _roninTokens,
    //    TokenStandard[] calldata _standards
    // );

    mainchainTokens = new address[](N);
    roninTokens = new address[](N);
    standards = new TokenStandard[](N);

    for (uint256 i; i < N; ++i) {
      mainchainTokens[i] = tokenInfos[i].mainchainToken;
      roninTokens[i] = tokenInfos[i].roninToken;
      standards[i] = tokenInfos[i].standard;
    }
  }

  function _cheatLocalReplaceGovernors(address[] memory governors) internal {
    bytes32 governorsSlot = keccak256(abi.encode(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc3830));
    console.logBytes32(governorsSlot);
    uint256 length = governors.length;

    // Cheat governors addresses.
    for (uint256 i; i < length; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      vm.store(_mainchainBridgeManager, governorSlotId, bytes32(uint256(uint160(governors[i]))));
    }

    // Check if cheat successfully.
    for (uint256 i; i < length; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      bytes32 afterCheatData = vm.load(_mainchainBridgeManager, bytes32(uint256(governorsSlot) + uint256(i)));

      assertEq(afterCheatData, bytes32(uint256(uint160(governors[i]))));
    }

    // Cheat governors weights.
    bytes32 governorsWeightSlot = bytes32(uint256(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300) + uint256(2));
    for (uint256 i; i < length; ++i) {
      address key = governors[i];
      bytes32 valueSlot = keccak256(abi.encode(key, governorsWeightSlot));
      vm.store(_mainchainBridgeManager, valueSlot, bytes32(uint256(uint96(100))));
    }
  }

  function _cheatWeightOperator(address gov) internal {
    // bytes32 governorsSlot = keccak256(abi.encode(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc3830));
    // vm.store(address(_roninBridgeManager), governorsSlot, bytes32(uint256(uint160(gov))));
    bytes32 governorsWeightSlot = bytes32(uint256(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300) + uint256(2));

    bytes32 $ = keccak256(abi.encode(gov, governorsWeightSlot));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(totalWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
    _roninBridgeManager.getGovernorWeight(gov);
  }
}
