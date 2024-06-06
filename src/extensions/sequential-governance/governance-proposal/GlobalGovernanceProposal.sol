// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../libraries/Proposal.sol";
import "../GlobalCoreGovernance.sol";
import "./CommonGovernanceProposal.sol";

abstract contract GlobalGovernanceProposal is GlobalCoreGovernance, CommonGovernanceProposal {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /**
   * @dev Proposes and casts votes for a global proposal by signatures.
   */
  function _proposeGlobalProposalStructAndCastVotes(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures,
    address creator
  ) internal returns (Proposal.ProposalDetail memory proposal) {
    proposal = _proposeGlobalStruct(globalProposal, creator);
    _castVotesBySignatures(proposal, supports_, signatures, globalProposal.hash());
  }

  /**
   * @dev Casts votes for a global proposal by signatures.
   */
  function _castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) internal {
    Proposal.ProposalDetail memory _proposal = globalProposal.intoProposalDetail(_resolveTargets({ targetOptions: globalProposal.targetOptions, strict: true }));

    bytes32 proposalHash = _proposal.hash();
    if (vote[0][_proposal.nonce].hash != proposalHash) {
      revert ErrInvalidProposal(proposalHash, vote[0][_proposal.nonce].hash);
    }

    _castVotesBySignatures(_proposal, supports_, signatures, globalProposal.hash());
  }

  /**
   * @dev See {CommonGovernanceProposal-_getProposalSignatures}
   */
  function getGlobalProposalSignatures(uint256 round_)
    external
    view
    returns (address[] memory voters, Ballot.VoteType[] memory supports_, Signature[] memory signatures)
  {
    return _getProposalSignatures(0, round_);
  }

  /**
   * @dev See {CommonGovernanceProposal-_proposalVoted}
   */
  function globalProposalVoted(uint256 round_, address voter) external view returns (bool) {
    return _proposalVoted(0, round_, voter);
  }
}
