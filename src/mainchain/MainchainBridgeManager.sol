// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { CoreGovernance } from "../extensions/sequential-governance/CoreGovernance.sol";
import { GlobalCoreGovernance, GlobalGovernanceRelay } from "../extensions/sequential-governance/governance-relay/GlobalGovernanceRelay.sol";
import { GovernanceRelay } from "../extensions/sequential-governance/governance-relay/GovernanceRelay.sol";
import { ContractType, BridgeManager } from "../extensions/bridge-operator-governance/BridgeManager.sol";
import { IMainchainGatewayV3 } from "../interfaces/IMainchainGatewayV3.sol";
import { TokenStandard } from "../libraries/LibTokenInfo.sol";
import { Ballot } from "../libraries/Ballot.sol";
import { Proposal } from "../libraries/Proposal.sol";
import { GlobalProposal } from "../libraries/GlobalProposal.sol";
import "../utils/CommonErrors.sol";

contract MainchainBridgeManager is BridgeManager, GovernanceRelay, GlobalGovernanceRelay {
  uint256 private constant DEFAULT_EXPIRY_DURATION = 1 << 255;

  function initialize(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights,
    GlobalProposal.TargetOption[] memory targetOptions,
    address[] memory targets
  ) external initializer {
    __CoreGovernance_init(DEFAULT_EXPIRY_DURATION);
    __GlobalCoreGovernance_init(targetOptions, targets);
    __BridgeManager_init(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights);
  }

  function hotfix__mapTokensAndThresholds_registerCallbacks() external onlyProxyAdmin {
    require(block.chainid == 1, "Only on ethereum-mainnet");

    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    address[] memory callbacks = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);
    uint256[][4] memory thresholds;

    mainchainTokens[0] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    roninTokens[0] = 0x7E73630F81647bCFD7B1F2C04c1C662D17d4577e;
    callbacks[0] = 0x64192819Ac13Ef72bF6b5AE239AC672B43a9AF08; // MainchainGatewayV3
    standards[0] = TokenStandard.ERC20;
    // highTierThreshold
    thresholds[0] = new uint256[](1);
    thresholds[0][0] = 17 * 10 ** 8;
    // lockedThreshold
    thresholds[1] = new uint256[](1);
    thresholds[1][0] = 34 * 10 ** 8;
    // unlockFeePercentages
    thresholds[2] = new uint256[](1);
    thresholds[2][0] = 10;
    // dailyWithdrawalLimit
    thresholds[3] = new uint256[](1);
    thresholds[3][0] = 42 * 10 ** 8;

    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    IMainchainGatewayV3 gateway = IMainchainGatewayV3(_resolveTargets({ targetOptions: targetOptions, strict: true })[0]);

    gateway.mapTokensAndThresholds({ _mainchainTokens: mainchainTokens, _roninTokens: roninTokens, _standards: standards, _thresholds: thresholds });
    _registerCallbacks(callbacks);
  }

  /**
   * @dev See `GovernanceRelay-_relayProposal`.
   *
   * Requirements:
   * - The method caller is governor.
   */
  function relayProposal(
    Proposal.ProposalDetail calldata proposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external onlyGovernor {
    _requireExecutor(proposal.executor, msg.sender);
    _relayProposal(proposal, supports_, signatures, msg.sender);
  }

  /**
   * @dev See `GovernanceRelay-_relayGlobalProposal`.
   *
   *  Requirements:
   * - The method caller is governor.
   */
  function relayGlobalProposal(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external onlyGovernor {
    _requireExecutor(globalProposal.executor, msg.sender);
    _relayGlobalProposal({ globalProposal: globalProposal, supports_: supports_, signatures: signatures, creator: msg.sender });
  }

  function _requireExecutor(address executor, address caller) internal pure {
    if (executor != address(0) && caller != executor) {
      revert ErrNonExecutorCannotRelay(executor, caller);
    }
  }

  /**
   * @dev Internal function to retrieve the minimum vote weight required for governance actions.
   * @return minimumVoteWeight The minimum vote weight required for governance actions.
   */
  function _getMinimumVoteWeight() internal view override returns (uint256) {
    return minimumVoteWeight();
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _proposalExpiryDuration;
  }

  /**
   * @dev Internal function to retrieve the total weights of all governors.
   * @return totalWeights The total weights of all governors combined.
   */
  function _getTotalWeight() internal view override returns (uint256) {
    return getTotalWeight();
  }

  /**
   * @dev Internal function to calculate the sum of weights for a given array of governors.
   * @param governors An array containing the addresses of governors to calculate the sum of weights.
   * @return sumWeights The sum of weights for the provided governors.
   */
  function _sumWeight(address[] memory governors) internal view override returns (uint256) {
    return _sumGovernorsWeight(governors);
  }

  /**
   * @dev Internal function to retrieve the chain type of the contract.
   * @return chainType The chain type, indicating the type of the chain the contract operates on (e.g., Mainchain).
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.Mainchain;
  }

  function _proposalDomainSeparator() internal view override returns (bytes32) {
    return DOMAIN_SEPARATOR;
  }
}
