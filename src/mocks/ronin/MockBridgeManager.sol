// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeManager, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";

contract MockBridgeManager is BridgeManager {
  function initialize(address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) external {
    BridgeManager.__init(0, 0, 0, address(0), _getEmptyAddressArray(), bridgeOperators, governors, voteWeights);
  }

  function _getEmptyAddressArray() internal pure returns (address[] memory arr) { }
}
