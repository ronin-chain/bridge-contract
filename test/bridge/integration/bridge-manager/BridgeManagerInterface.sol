// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { SignerUtils } from "@ronin/test/utils/Signers.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";

contract BridgeManagerInterface is SignerUtils {
  RoninBridgeManager internal _contract;
  Account[] internal _signers;

  constructor(RoninBridgeManager bridgeManager, Account[] memory signers) {
    _contract = bridgeManager;
    _setSigners(signers);
  }

  function _setSigners(Account[] memory signers) internal {
    delete _signers;
    for (uint256 i; i < signers.length; i++) {
      _signers.push(signers[i]);
    }
  }

  function createGlobalProposal(
    uint256 expiryTs,
    GlobalProposal.TargetOption targetOption,
    uint256 value_,
    bytes memory calldata_,
    uint256 gasAmount_,
    uint256 nonce_
  ) public view returns (GlobalProposal.GlobalProposalDetail memory rs) { }
}
