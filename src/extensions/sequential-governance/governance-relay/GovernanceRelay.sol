// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../CoreGovernance.sol";
import "./CommonGovernanceRelay.sol";

abstract contract GovernanceRelay is CoreGovernance, CommonGovernanceRelay {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /**
   * @dev Relays voted proposal.
   *
   * Requirements:
   * - The relay proposal is finalized.
   *
   */
  function _relayProposal(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    address _creator
  ) internal {
    _proposeProposalStruct(_proposal, _creator);
    _relayVotesBySignatures(_proposal, _supports, _signatures, _proposal.hash());
  }
}
