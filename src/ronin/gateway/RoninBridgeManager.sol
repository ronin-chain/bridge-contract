// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, RoleAccess, ErrUnauthorized, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import {
  Ballot,
  GlobalProposal,
  Proposal,
  CommonGovernanceProposal,
  GovernanceProposal
} from "../../extensions/sequential-governance/governance-proposal/GovernanceProposal.sol";
import {
  CoreGovernance,
  GlobalCoreGovernance,
  GlobalGovernanceProposal
} from "../../extensions/sequential-governance/governance-proposal/GlobalGovernanceProposal.sol";
import { IRoninGatewayV3 } from "../../interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "../../extensions/MinimumWithdrawal.sol";
import { TokenStandard } from "../../libraries/LibTokenInfo.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import "../../utils/CommonErrors.sol";

contract RoninBridgeManager is BridgeManager, GovernanceProposal, GlobalGovernanceProposal {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  function hotfix__mapToken_setMinimumThresholds_registerCallbacks() external onlyProxyAdmin {
    require(block.chainid == 2020, "Only on ronin-mainnet");

    address[] memory roninTokens = new address[](1);
    address[] memory mainchainTokens = new address[](1);
    uint256[] memory chainIds = new uint256[](1);
    address[] memory callbacks = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);
    uint256[] memory withdrawalThresholds = new uint256[](1);

    roninTokens[0] = 0x7E73630F81647bCFD7B1F2C04c1C662D17d4577e;
    mainchainTokens[0] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    chainIds[0] = 1;
    callbacks[0] = 0x273cdA3AFE17eB7BcB028b058382A9010ae82B24; // Bridge Slash contract
    standards[0] = TokenStandard.ERC20;
    withdrawalThresholds[0] = 0.000167 * 10 ** 8;

    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    address gw = _resolveTargets({ targetOptions: targetOptions, strict: true })[0];

    IRoninGatewayV3(gw).mapTokens({ _roninTokens: roninTokens, _mainchainTokens: mainchainTokens, chainIds: chainIds, _standards: standards });
    MinimumWithdrawal(gw).setMinimumThresholds({ _tokens: mainchainTokens, _thresholds: withdrawalThresholds });

    _registerCallbacks(callbacks);
  }

  /**
   * CURRENT NETWORK
   */

  /**
   * @dev See `CoreGovernance-_proposeProposal`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function propose(
    uint256 chainId,
    uint256 expiryTimestamp,
    address executor,
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    uint256[] calldata gasAmounts
  ) external onlyGovernor {
    _proposeProposalStruct(
      Proposal.ProposalDetail({
        nonce: _createVotingRound(chainId),
        chainId: chainId,
        expiryTimestamp: expiryTimestamp,
        executor: executor,
        targets: targets,
        values: values,
        calldatas: calldatas,
        gasAmounts: gasAmounts
      }),
      msg.sender
    );
  }

  /**
   * @dev See `GovernanceProposal-_proposeProposalStructAndCastVotes`.
   *
   * Requirements:
   * - The method caller is governor.
   * - The proposal is for the current network.
   *
   */
  function proposeProposalStructAndCastVotes(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyGovernor {
    _proposeProposalStructAndCastVotes(_proposal, _supports, _signatures, msg.sender);
  }

  /**
   * @dev Proposes and casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   * - The proposal is for the current network.
   *
   */
  function proposeProposalForCurrentNetwork(
    uint256 expiryTimestamp,
    address executor,
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    uint256[] calldata gasAmounts,
    Ballot.VoteType support
  ) external onlyGovernor {
    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: _createVotingRound(block.chainid),
      chainId: block.chainid,
      expiryTimestamp: expiryTimestamp,
      executor: executor,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
    _proposeProposalStruct(proposal, msg.sender);
    _castProposalVoteForCurrentNetwork(msg.sender, proposal, support);
  }

  /**
   * @dev Casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function castProposalVoteForCurrentNetwork(Proposal.ProposalDetail calldata proposal, Ballot.VoteType support) external onlyGovernor {
    _castProposalVoteForCurrentNetwork(msg.sender, proposal, support);
  }

  /**
   * @dev See `GovernanceProposal-_castProposalBySignatures`.
   */
  function castProposalBySignatures(Proposal.ProposalDetail calldata proposal, Ballot.VoteType[] calldata supports_, Signature[] calldata signatures) external {
    _castProposalBySignatures(proposal, supports_, signatures);
  }

  /**
   * GLOBAL NETWORK
   */

  /**
   * @dev See `CoreGovernance-_proposeGlobal`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function proposeGlobal(
    uint256 expiryTimestamp,
    address executor,
    GlobalProposal.TargetOption[] calldata targetOptions,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    uint256[] calldata gasAmounts
  ) external onlyGovernor {
    _proposeGlobal({
      expiryTimestamp: expiryTimestamp,
      executor: executor,
      targetOptions: targetOptions,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts,
      creator: msg.sender
    });
  }

  /**
   * @dev See `GovernanceProposal-_proposeGlobalProposalStructAndCastVotes`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function proposeGlobalProposalStructAndCastVotes(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external onlyGovernor {
    _proposeGlobalProposalStructAndCastVotes({ globalProposal: globalProposal, supports_: supports_, signatures: signatures, creator: msg.sender });
  }

  /**
   * @dev See `GovernanceProposal-_castGlobalProposalBySignatures`.
   */
  function castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external {
    _castGlobalProposalBySignatures({ globalProposal: globalProposal, supports_: supports_, signatures: signatures });
  }

  /**
   * COMMON METHODS
   */

  /**
   * @dev See {CoreGovernance-_executeWithCaller}.
   */
  function execute(Proposal.ProposalDetail calldata proposal) external {
    _executeWithCaller(proposal, msg.sender);
  }

  /**
   * @dev See {GlobalCoreGovernance-_executeWithCaller}.
   */
  function executeGlobal(GlobalProposal.GlobalProposalDetail calldata globalProposal) external {
    _executeWithCaller({
      proposal: globalProposal.intoProposalDetail(_resolveTargets({ targetOptions: globalProposal.targetOptions, strict: true })),
      caller: msg.sender
    });
  }

  /**
   * @dev Deletes the expired proposal by its chainId and nonce, without creating a new proposal.
   *
   * Requirements:
   * - The proposal is already created.
   *
   */
  function deleteExpired(uint256 _chainId, uint256 _round) external {
    ProposalVote storage _vote = vote[_chainId][_round];
    if (_vote.hash == 0) revert ErrQueryForEmptyVote();

    _tryDeleteExpiredVotingRound(_vote);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _proposalExpiryDuration;
  }

  /**
   * @dev Internal function to get the chain type of the contract.
   * @return The chain type, indicating the type of the chain the contract operates on (e.g., RoninChain).
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.RoninChain;
  }

  /**
   * @dev Internal function to get the total weights of all governors.
   * @return The total weights of all governors combined.
   */
  function _getTotalWeight() internal view virtual override returns (uint256) {
    return getTotalWeight();
  }

  /**
   * @dev Internal function to get the minimum vote weight required for governance actions.
   * @return The minimum vote weight required for governance actions.
   */
  function _getMinimumVoteWeight() internal view virtual override returns (uint256) {
    return minimumVoteWeight();
  }

  /**
   * @dev Internal function to get the vote weight of a specific governor.
   * @param _governor The address of the governor to get the vote weight for.
   * @return The vote weight of the specified governor.
   */
  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    return _getGovernorWeight(_governor);
  }

  function _proposalDomainSeparator() internal view override returns (bytes32) {
    return DOMAIN_SEPARATOR;
  }
}
