// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ronin/contracts/libraries/GlobalProposal.sol";

struct MaintenanceArguments {
  uint256 minMaintenanceDurationInBlock;
  uint256 maxMaintenanceDurationInBlock;
  uint256 minOffsetToStartSchedule;
  uint256 maxOffsetToStartSchedule;
  uint256 maxSchedules;
  uint256 cooldownSecsToMaintain;
}

struct StakingArguments {
  uint256 minValidatorStakingAmount;
  uint256 minCommissionRate;
  uint256 maxCommissionRate;
  uint256 cooldownSecsToUndelegate;
  uint256 waitingSecsToRevoke;
}

struct StakingVestingArguments {
  uint256 blockProducerBonusPerBlock;
  uint256 bridgeOperatorBonusPerBlock;
  uint256 topupAmount;
  uint256 fastFinalityRewardPercent;
}

struct BridgeOperatorSlashingConfig {
  uint256 missingVotesRatioTier1;
  uint256 missingVotesRatioTier2;
  uint256 jailDurationForMissingVotesRatioTier2;
  uint256 skipBridgeOperatorSlashingThreshold;
}

struct BridgeVotingSlashingConfig {
  uint256 bridgeVotingThreshold;
  uint256 bridgeVotingSlashAmount;
}

struct DoubleSignSlashingConfig {
  uint256 slashDoubleSignAmount;
  uint256 doubleSigningJailUntilBlock;
  uint256 doubleSigningOffsetLimitBlock;
}

struct UnavailabilitySlashing {
  uint256 unavailabilityTier1Threshold;
  uint256 unavailabilityTier2Threshold;
  uint256 slashAmountForUnavailabilityTier2Threshold;
  uint256 jailDurationForUnavailabilityTier2Threshold;
}

struct CreditScoreConfig {
  uint256 gainCreditScore;
  uint256 maxCreditScore;
  uint256 bailOutCostMultiplier;
  uint256 cutOffPercentageAfterBailout;
}

struct SlashIndicatorArguments {
  BridgeOperatorSlashingConfig bridgeOperatorSlashing;
  BridgeVotingSlashingConfig bridgeVotingSlashing;
  DoubleSignSlashingConfig doubleSignSlashing;
  UnavailabilitySlashing unavailabilitySlashing;
  CreditScoreConfig creditScore;
}

struct RoninValidatorSetArguments {
  uint256 maxValidatorNumber;
  uint256 maxValidatorCandidate;
  uint256 maxPrioritizedValidatorNumber;
  uint256 numberOfBlocksInEpoch;
  uint256 minEffectiveDaysOnwards;
  uint256 emergencyExitLockedAmount;
  uint256 emergencyExpiryDuration;
}

struct TrustedOrganization {
  address consensusAddr;
  address governor;
  address bridgeVoter;
  uint256 weight;
  uint256 addedBlock;
}

struct RoninTrustedOrganizationArguments {
  TrustedOrganization[] trustedOrganizations;
  uint256 numerator;
  uint256 denominator;
}

struct RoninGovernanceAdminArguments {
  uint256 proposalExpiryDuration;
}

struct TargetOptionStruct {
  GlobalProposal.TargetOption option;
  address target;
}

struct BridgeManagerMemberStruct {
  address governor;
  address operator;
  uint96 weight;
}

struct BridgeManagerArguments {
  uint256 numerator;
  uint256 denominator;
  uint256 expiryDuration;
  BridgeManagerMemberStruct[] members;
  TargetOptionStruct[] targets;
}

struct BridgeRewardArguments {
  uint256 rewardPerPeriod;
  uint256 topupAmount;
}

struct AddressExtended {
  address addr;
  uint256 nonce;
}

struct GeneralConfig {
  uint256 roninChainId;
  address bridgeContract;
  uint256 startedAtBlock;
  AddressExtended governanceAdmin;
  AddressExtended maintenanceContract;
  AddressExtended fastFinalityTrackingContract;
  AddressExtended stakingVestingContract;
  AddressExtended slashIndicatorContract;
  AddressExtended stakingContract;
  AddressExtended validatorContract;
  AddressExtended roninTrustedOrganizationContract;
  AddressExtended bridgeTrackingContract;
  AddressExtended bridgeManagerContract;
  AddressExtended bridgeSlashContract;
  AddressExtended bridgeRewardContract;
}

struct InitTestInput {
  GeneralConfig roninGeneralConfig;
  GeneralConfig mainchainGeneralConfig;
  MaintenanceArguments maintenanceArguments;
  StakingArguments stakingArguments;
  StakingVestingArguments stakingVestingArguments;
  SlashIndicatorArguments slashIndicatorArguments;
  RoninValidatorSetArguments roninValidatorSetArguments;
  RoninTrustedOrganizationArguments roninTrustedOrganizationArguments;
  RoninGovernanceAdminArguments governanceAdminArguments;
  BridgeManagerArguments bridgeManagerArguments;
  BridgeRewardArguments bridgeRewardArguments;
}

struct InitTestOutput {
  address payable bridgeContractAddress;
  address payable roninGovernanceAdminAddress;
  address payable maintenanceContractAddress;
  address payable roninTrustedOrganizationAddress;
  address payable fastFinalityTrackingAddress;
  address payable slashContractAddress;
  address payable stakingContractAddress;
  address payable stakingVestingContractAddress;
  address payable validatorContractAddress;
  address payable bridgeTrackingAddress;
  address payable bridgeSlashAddress;
  address payable bridgeRewardAddress;
  address payable roninBridgeManagerAddress;
  address payable mainchainBridgeManagerAddress;
}
