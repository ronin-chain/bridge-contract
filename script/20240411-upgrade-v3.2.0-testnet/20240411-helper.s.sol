// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import "../BridgeMigration.sol";

struct LegacyProposalDetail {
  uint256 nonce;
  uint256 chainId;
  uint256 expiryTimestamp;
  address[] targets;
  uint256[] values;
  bytes[] calldatas;
  uint256[] gasAmounts;
}

contract Migration__20240409_Helper is BridgeMigration {
  address internal _governor;
  address[] internal _voters;

  RoninBridgeManager internal _currRoninBridgeManager;
  RoninBridgeManager internal _newRoninBridgeManager;

  function _helperProposeForCurrentNetwork(LegacyProposalDetail memory proposal) internal {
    vm.broadcast(_governor);
    address(_currRoninBridgeManager).call(
      abi.encodeWithSignature(
        "proposeProposalForCurrentNetwork(uint256,address[],uint256[],bytes[],uint256[],uint8)",
        // proposal.chainId,
        proposal.expiryTimestamp,
        proposal.targets,
        proposal.values,
        proposal.calldatas,
        proposal.gasAmounts,
        Ballot.VoteType.For
      )
    );
  }

  function _helperVoteForCurrentNetwork(LegacyProposalDetail memory proposal) internal {
    for (uint i; i < _voters.length; ++i) {
      vm.broadcast(_voters[i]);
      address(_currRoninBridgeManager).call(
        abi.encodeWithSignature(
          "castProposalVoteForCurrentNetwork((uint256,uint256,uint256,address[],uint256[],bytes[],uint256[]),uint8)", proposal, Ballot.VoteType.For
        )
      );
    }
  }
}
