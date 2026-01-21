// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MapTokenInfo } from "../libraries/MapTokenInfo.sol";

/**
 * @title YGG Token Bridge Configuration
 * @dev Optimized for Ronin Network migration. 
 * Includes explicit scale constants to prevent decimal math errors.
 */
contract Migration__MapToken_Ygg_Config {
    // Constants for fee scale to ensure auditability
    uint256 public constant FEE_DENOMINATOR = 1_000_000;
    
    MapTokenInfo internal _yggInfo;

    constructor() {
        // YGG Token on Ronin Network
        _yggInfo.roninToken = address(0x1c306872bC82525d72Bf3562E8F0aA3f8F26e857);
        // YGG Token on Ethereum Mainchain
        _yggInfo.mainchainToken = address(0x25f8087EAD173b73D6e8B84329989A8eEA16CF73);
        
        // Bridging Thresholds (Standardized to 18 decimals)
        _yggInfo.minThreshold = 20 ether;
        _yggInfo.highTierThreshold = 1_000_000 ether;
        _yggInfo.lockedThreshold = 2_000_000 ether;
        _yggInfo.dailyWithdrawalLimit = 2_000_000 ether;

        // Fee Logic: 10 units = 0.001% (assuming 1e6 scale)
        // Audit Recommendation: Ensure the Bridge logic uses FEE_DENOMINATOR correctly.
        _yggInfo.unlockFeePercentages = 10; 
    }

    /**
     * @notice Returns the YGG bridging configuration for external verification.
     */
    function getYggConfig() external view returns (MapTokenInfo memory) {
        return _yggInfo;
    }
}
