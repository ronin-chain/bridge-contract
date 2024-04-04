// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { TNetwork } from "@fdk/types/Types.sol";

interface IGeneralConfigExtended is IGeneralConfig {
  /**
   * @dev Returns the companion mainchain network of a roninchain network
   *
   * Input: roninchain network
   * Output: companion mainchain network of roninchain
   *
   */
  function getCompanionNetwork(TNetwork network) external pure returns (TNetwork);
}
