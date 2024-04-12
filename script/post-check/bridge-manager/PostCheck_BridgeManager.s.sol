// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PostCheck_BridgeManager_CRUD_AddBridgeOperators } from "./crud/PostCheck_BridgeManager_CRUD_AddBridgeOperators.s.sol";
import { PostCheck_BridgeManager_CRUD_RemoveBridgeOperators } from "./crud/PostCheck_BridgeManager_CRUD_RemoveBridgeOperators.s.sol";
import { PostCheck_BridgeManager_Proposal } from "./proposal/PostCheck_BridgeManager_Proposal.s.sol";

abstract contract PostCheck_BridgeManager is
  PostCheck_BridgeManager_Proposal,
  PostCheck_BridgeManager_CRUD_AddBridgeOperators,
  PostCheck_BridgeManager_CRUD_RemoveBridgeOperators
{
  function _validate_BridgeManager() internal onPostCheck("validate_BridgeManager") {
    _validate_BridgeManager_CRUD_addBridgeOperators();
    _validate_BridgeManager_CRUD_removeBridgeOperators();
    _validate_BridgeManager_Proposal();
  }
}
