// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { Migration } from "../Migration.s.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";

struct LegacyProposalDetail {
  uint256 nonce;
  uint256 chainId;
  uint256 expiryTimestamp;
  address[] targets;
  uint256[] values;
  bytes[] calldatas;
  uint256[] gasAmounts;
}

contract Migration__20240716_Helper is Migration {
  address internal _proposer;
  address[] internal _voters;

  IRoninBridgeManager internal _currRoninBridgeManager;

  function _helperProposeForCurrentNetwork(LegacyProposalDetail memory proposal) internal {
    console.log("Real start broadcast to propose proposal:", _proposer);
    vm.startBroadcast(_proposer);
    (bool success,) = address(_currRoninBridgeManager).call(
      abi.encodeWithSignature(
        "proposeProposalForCurrentNetwork(uint256,address[],uint256[],bytes[],uint256[],uint8)",
        proposal.expiryTimestamp,
        proposal.targets,
        proposal.values,
        proposal.calldatas,
        proposal.gasAmounts,
        Ballot.VoteType.For
      )
    );
    require(success, "proposeProposalForCurrentNetwork failed");
    vm.stopBroadcast();
  }

  function _helperVoteForCurrentNetwork(LegacyProposalDetail memory proposal) internal {
    for (uint i; i < _voters.length - 1; ++i) {
      if (_voters[i] == _proposer) {
        continue;
      }

      vm.prank(_voters[i]);
      (bool success,) = address(_currRoninBridgeManager).call{ gas: (proposal.targets.length + 1) * 1_000_000 }(
        abi.encodeWithSignature(
          "castProposalVoteForCurrentNetwork((uint256,uint256,uint256,address[],uint256[],bytes[],uint256[]),uint8)", proposal, Ballot.VoteType.For
        )
      );
      require(success, "castProposalVoteForCurrentNetwork failed");
    }
  }
}
