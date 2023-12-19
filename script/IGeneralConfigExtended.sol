// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "foundry-deployment-kit/interfaces/IGeneralConfig.sol";
import { TNetwork } from "foundry-deployment-kit/types/Types.sol";
import { Network } from "./utils/Network.sol";

interface IGeneralConfigExtended is IGeneralConfig {
  /**
   * @dev Returns the companion mainchain network of a roninchain network
   *
   * Input: roninchain network
   * Output: companion mainchain network of roninchain
   *
   */
  function getCompanionNetwork(TNetwork network) external pure returns (Network);
}
