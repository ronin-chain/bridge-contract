// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Contract } from "../../utils/Contract.sol";
import { Migration } from "../../Migration.s.sol";
import { Network } from "../../utils/Network.sol";
import { Contract } from "../../utils/Contract.sol";
import { IGeneralConfigExtended } from "../../interfaces/IGeneralConfigExtended.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { MapTokenInfo } from "../../libraries/MapTokenInfo.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

abstract contract Factory__MapTokensRoninchain is Migration {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;
  address internal _specifiedCaller;
  address[] internal _governors;

  function run() public virtual {
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
    _specifiedCaller = _initCaller();
  }

  function _initCaller() internal virtual returns (address);
  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos);

  function _proposeAndExecuteProposal(Proposal.ProposalDetail memory proposal) internal {
    proposal.executor = _specifiedCaller;
    _propose(proposal);
    _executeProposal(proposal);
  }

  function _propose(Proposal.ProposalDetail memory proposal) internal {
    vm.broadcast(_specifiedCaller);
    _roninBridgeManager.propose(
      proposal.chainId, proposal.expiryTimestamp, proposal.executor, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts
    );
  }

  function _executeProposal(Proposal.ProposalDetail memory proposal) internal {
    uint256 minVoteWeight = _roninBridgeManager.minimumVoteWeight();
    uint256 sumVoteWeight;
    uint256 numberGovernorsNeedToVote;

    for (uint256 i; i < _governors.length; ++i) {
      sumVoteWeight += _roninBridgeManager.getGovernorWeight(_governors[i]);
      numberGovernorsNeedToVote++;
      if (sumVoteWeight >= minVoteWeight) break;
    }
    require(sumVoteWeight > 0 && numberGovernorsNeedToVote > 0);

    for (uint256 i; i < numberGovernorsNeedToVote; ++i) {
      vm.broadcast(_governors[i]);
      _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    }

    uint256 gasAmounts = 1_000_000;
    for (uint256 i; i < proposal.gasAmounts.length; ++i) {
      gasAmounts += proposal.gasAmounts[i];
    }

    vm.broadcast(_specifiedCaller);
    _roninBridgeManager.execute{ gas: gasAmounts }(proposal);
  }

  function _createAndVerifyProposalOnRonin() internal returns (Proposal.ProposalDetail memory proposal) {
    _initTokenList();

    (address[] memory roninTokens, address[] memory mainchainTokens, uint256[] memory chainIds, TokenStandard[] memory standards) = _prepareMapTokens();

    // Assume that all tokens have the same standard.
    TokenStandard tokenStandard = standards[0];

    address[] memory targets;
    uint256[] memory values;
    bytes[] memory calldatas;
    uint256[] memory gasAmounts;

    targets = new address[](1);
    values = new uint256[](1);
    calldatas = new bytes[](1);
    gasAmounts = new uint256[](1);

    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    uint256 expiry = block.timestamp + 14 days;
    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    if (tokenStandard == TokenStandard.ERC20) {
      targets = new address[](2);
      values = new uint256[](2);
      calldatas = new bytes[](2);
      gasAmounts = new uint256[](2);

      expiry = block.timestamp + 14 days;
      targets[0] = _roninGatewayV3;
      values[0] = 0;
      calldatas[0] = proxyData;
      gasAmounts[0] = 1_000_000;

      (address[] memory roninTokensToSetMinThreshold, uint256[] memory minThresholds) = _prepareSetMinThreshold();

      innerData = abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (roninTokensToSetMinThreshold, minThresholds));
      proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

      targets[1] = _roninGatewayV3;
      values[1] = 0;
      calldatas[1] = proxyData;
      gasAmounts[1] = 1_000_000;
    }

    LibProposal.verifyProposalGasAmount(address(_roninBridgeManager), targets, values, calldatas, gasAmounts);

    proposal = Proposal.ProposalDetail({
      nonce: RoninBridgeManager(_roninBridgeManager).round(block.chainid) + 1,
      chainId: block.chainid,
      expiryTimestamp: expiry,
      executor: address(0),
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
  }

  function _prepareMapTokens()
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
      standards[i] = tokenInfos[i].standard;
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
