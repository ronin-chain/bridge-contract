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
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import "../../utils/CommonErrors.sol";

contract RoninBridgeManagerConstructor is BridgeManager, GovernanceProposal, GlobalGovernanceProposal {
  using Proposal for Proposal.ProposalDetail;

  function initialize(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights,
    GlobalProposal.TargetOption[] memory targetOptions,
    address[] memory targets
  ) external initializer {
    __CoreGovernance_init(expiryDuration);
    __GlobalCoreGovernance_init(targetOptions, targets);
    __BridgeManager_init(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights);
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
