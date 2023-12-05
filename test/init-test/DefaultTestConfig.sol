// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Structs.sol";

library DefaultTestConfig {
  function get() public pure returns (InitTestInput memory rs) {
    rs.roninGeneralConfig.bridgeContract = address(0);
    rs.roninGeneralConfig.startedAtBlock = 0;
    rs.mainchainGeneralConfig.bridgeContract = address(0);
    rs.mainchainGeneralConfig.startedAtBlock = 0;

    // maintenanceArguments
    rs.maintenanceArguments.minMaintenanceDurationInBlock = 100;
    rs.maintenanceArguments.maxMaintenanceDurationInBlock = 1000;
    rs.maintenanceArguments.minOffsetToStartSchedule = 200;
    rs.maintenanceArguments.maxOffsetToStartSchedule = 200 * 7;
    rs.maintenanceArguments.maxSchedules = 2;
    rs.maintenanceArguments.cooldownSecsToMaintain = 0;

    // stakingArguments
    rs.stakingArguments.minValidatorStakingAmount = 100;
    rs.stakingArguments.maxCommissionRate = 100;
    rs.stakingArguments.cooldownSecsToUndelegate = 3 * 86400;
    rs.stakingArguments.waitingSecsToRevoke = 7 * 86400;

    //stakingVestingArguments
    rs.stakingVestingArguments.blockProducerBonusPerBlock = 1000;
    rs.stakingVestingArguments.bridgeOperatorBonusPerBlock = 1000;
    rs.stakingVestingArguments.topupAmount = 100_000_000_000;
    rs.stakingVestingArguments.fastFinalityRewardPercent = 1_00;

    //slashIndicatorArguments.bridgeOperatorSlashing
    rs.slashIndicatorArguments.bridgeOperatorSlashing.missingVotesRatioTier1 = 10_00;
    rs.slashIndicatorArguments.bridgeOperatorSlashing.missingVotesRatioTier2 = 20_00;
    rs.slashIndicatorArguments.bridgeOperatorSlashing.jailDurationForMissingVotesRatioTier2 = 28800 * 2;
    rs.slashIndicatorArguments.bridgeOperatorSlashing.skipBridgeOperatorSlashingThreshold = 10;

    //slashIndicatorArguments.bridgeVotingSlashing
    rs.slashIndicatorArguments.bridgeVotingSlashing.bridgeVotingThreshold = 28800 * 3;
    rs.slashIndicatorArguments.bridgeVotingSlashing.bridgeVotingSlashAmount = 10_000 * 1e18;

    //slashIndicatorArguments.doubleSignSlashing
    rs.slashIndicatorArguments.doubleSignSlashing.slashDoubleSignAmount = 10 * 1e18;
    rs.slashIndicatorArguments.doubleSignSlashing.doubleSigningJailUntilBlock = type(uint256).max;
    rs.slashIndicatorArguments.doubleSignSlashing.doubleSigningOffsetLimitBlock = 28800;

    //slashIndicatorArguments.unavailabilitySlashing
    rs.slashIndicatorArguments.unavailabilitySlashing.unavailabilityTier1Threshold = 5;
    rs.slashIndicatorArguments.unavailabilitySlashing.unavailabilityTier2Threshold = 10;
    rs.slashIndicatorArguments.unavailabilitySlashing.slashAmountForUnavailabilityTier2Threshold = 1e18;
    rs.slashIndicatorArguments.unavailabilitySlashing.jailDurationForUnavailabilityTier2Threshold = 28800;

    //slashIndicatorArguments.creditScore
    rs.slashIndicatorArguments.creditScore.gainCreditScore = 50;
    rs.slashIndicatorArguments.creditScore.maxCreditScore = 600;
    rs.slashIndicatorArguments.creditScore.bailOutCostMultiplier = 5;
    rs.slashIndicatorArguments.creditScore.cutOffPercentageAfterBailout = 50_00;

    //roninValidatorSetArguments
    rs.roninValidatorSetArguments.maxValidatorNumber = 4;
    rs.roninValidatorSetArguments.maxPrioritizedValidatorNumber = 0;
    rs.roninValidatorSetArguments.numberOfBlocksInEpoch = 600;
    rs.roninValidatorSetArguments.maxValidatorCandidate = 10;
    rs.roninValidatorSetArguments.minEffectiveDaysOnwards = 7;
    rs.roninValidatorSetArguments.emergencyExitLockedAmount = 500;
    rs.roninValidatorSetArguments.emergencyExpiryDuration = 14 * 86400;

    //roninTrustedOrganizationArguments
    // rs.roninTrustedOrganizationArguments.trustedOrganizations = new TrustedOrganization[](0);
    rs.roninTrustedOrganizationArguments.numerator = 0;
    rs.roninTrustedOrganizationArguments.denominator = 1;

    //governanceAdminArguments
    rs.governanceAdminArguments.proposalExpiryDuration = 60 * 60 * 24 * 14; // 14 days

    //bridgeManagerArguments
    rs.bridgeManagerArguments.numerator = 70;
    rs.bridgeManagerArguments.denominator = 100;
    rs.bridgeManagerArguments.expiryDuration = 60 * 60 * 24 * 14; // 14 days
    rs.bridgeManagerArguments.members = new BridgeManagerMemberStruct[](0);
    rs.bridgeManagerArguments.targets = new TargetOptionStruct[](0);

    //bridgeRewardArguments
    rs.bridgeRewardArguments.rewardPerPeriod = 5_000;
    rs.bridgeRewardArguments.topupAmount = 100_000_000_000;
  }
}
