// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../interfaces/IGeneralConfigExtended.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

abstract contract Factory__MapTokensRoninchain is Migration {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;
  address private _governor;
  address[] internal _governors;

  function setUp() public virtual override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    _governor = _initCaller();
    _cheatWeightOperator(_governor);

    _governors = new address[](4);
    _governors[3] = address(0);
    _governors[2] = address(0);
    _governors[0] = address(0);
    _governors[1] = address(0);
  }

  function run() public virtual {
    _proposeAndCastVoteForProposal();
  }

  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function _proposeAndCastVoteForProposal() internal {
    Proposal.ProposalDetail memory proposal = _proposeProposal();

    uint256 minVoteWeight = _roninBridgeManager.minimumVoteWeight();
    uint256 sumVoteWeight;
    uint256 amountGovernorsNeedToVote;

    for (uint256 i; i < _governors.length; ++i) {
      sumVoteWeight += _roninBridgeManager.getGovernorWeight(_governors[i]);
      amountGovernorsNeedToVote++;
      if (sumVoteWeight >= minVoteWeight) break;
    }
    require(sumVoteWeight > 0 && amountGovernorsNeedToVote > 0);

    for (uint256 i; i < amountGovernorsNeedToVote; ++i) {
      vm.broadcast(_governors[i]);
      _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    }
  }

  function _proposeProposal() internal virtual returns (Proposal.ProposalDetail memory proposal) {
    proposal = _createAndVerifyProposal();

    vm.broadcast(_governor);
    _roninBridgeManager.propose(
      proposal.chainId, proposal.expiryTimestamp, proposal.executor, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts
    );
  }

  function _createAndVerifyProposal() internal returns (Proposal.ProposalDetail memory proposal) {
    (address[] memory roninTokens, address[] memory mainchainTokens, uint256[] memory chainIds, TokenStandard[] memory standards) = _prepareMapToken();
    (address[] memory roninTokensToSetMinThreshold, uint256[] memory minThresholds) = _prepareSetMinThreshold();

    address[] memory targets = new address[](2);
    uint256[] memory values = new uint256[](2);
    bytes[] memory calldatas = new bytes[](2);
    uint256[] memory gasAmounts = new uint256[](2);

    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    uint256 expiredTime = block.timestamp + 14 days;
    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    innerData = abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (roninTokensToSetMinThreshold, minThresholds));
    proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[1] = _roninGatewayV3;
    values[1] = 0;
    calldatas[1] = proxyData;
    gasAmounts[1] = 1_000_000;

    LibProposal.verifyProposalGasAmount(address(_roninBridgeManager), targets, values, calldatas, gasAmounts);

    proposal = Proposal.ProposalDetail({
      nonce: RoninBridgeManager(_roninBridgeManager).round(2021) + 1,
      chainId: block.chainid,
      expiryTimestamp: expiredTime,
      executor: 0x0000000000000000000000000000000000000000,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
  }

  function _cheatWeightOperator(address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
  }

  function _prepareMapToken()
    internal
    returns (address[] memory roninTokens, address[] memory mainchainTokens, uint256[] memory chainIds, TokenStandard[] memory standards)
  {
    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata _standards
    // )
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();

    roninTokens = new address[](N);
    mainchainTokens = new address[](N);
    chainIds = new uint256[](N);
    standards = new TokenStandard[](N);

    // ============= MAP TOKENS ===========

    for (uint256 i; i < N; ++i) {
      roninTokens[i] = tokenInfos[i].roninToken;
      mainchainTokens[i] = tokenInfos[i].mainchainToken;
      chainIds[i] = network().companionChainId();
      standards[i] = TokenStandard.ERC20;
    }
  }

  function _prepareSetMinThreshold() internal returns (address[] memory roninTokensToSetMinThreshold, uint256[] memory minThresholds) {
    (uint256 N, MapTokenInfo[] memory tokenInfos) = _initTokenList();

    // ============= SET MIN THRESHOLD ============
    // function setMinimumThresholds(
    //   address[] calldata _tokens,
    //   uint256[] calldata _thresholds
    // );
    roninTokensToSetMinThreshold = new address[](N);
    minThresholds = new uint256[](N);

    for (uint256 i; i < N; ++i) {
      roninTokensToSetMinThreshold[i] = tokenInfos[i].roninToken;
      minThresholds[i] = tokenInfos[i].minThreshold;
    }
  }
}
