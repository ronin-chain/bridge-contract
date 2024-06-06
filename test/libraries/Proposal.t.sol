// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";

contract ProposalTest is Test {
  // keccak256("GlobalProposalDetail(uint256 nonce,uint256 expiryTimestamp,address executor,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 internal constant GLOBAL_TYPE_HASH = 0xde480f0c53a3651c08fbab1dffbc45fe574f31188827fe52cb9035da9fe57e4a;
  // keccak256("ProposalDetail(uint256 nonce,uint256 chainId,uint256 expiryTimestamp,address executor,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 internal constant TYPE_HASH = 0x1b59eeec7c321899dc1e7a5b3d876c9a445dffc6d2f96ba842d7489908fdee12;

  function testFuzz_hash_Proposal(uint256 nonce, uint256 chainId, uint256 expiryTimestamp, address executor, uint8 count) external returns (bytes32) {
    vm.assume(count < 100 && count != 0);

    address[] memory targets = new address[](count);
    uint256[] memory values = new uint256[](count);
    bytes[] memory calldatas = new bytes[](count);
    uint256[] memory gasAmounts = new uint256[](count);

    for (uint8 i = 0; i < count; i++) {
      targets[i] = address(uint160(uint256(keccak256(abi.encodePacked("targets[i]", i)))));
      values[i] = uint256(keccak256(abi.encodePacked("values[i]", i)));
      calldatas[i] = abi.encodePacked("calldatas[i]", i);
      gasAmounts[i] = uint256(keccak256(abi.encodePacked("gasAmounts[i]", i)));
    }

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: nonce,
      chainId: chainId,
      expiryTimestamp: expiryTimestamp,
      executor: executor,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
    bytes32 actual = Proposal.hash(proposal);
    bytes32 expected = hash(proposal);

    assertEq(actual, expected, "hash mismatch");
  }

  function testFuzz_hash_GlobalProposal(uint256 nonce, uint256 expiryTimestamp, address executor, uint8 count) external returns (bytes32) {
    vm.assume(count < 100 && count != 0);

    uint8[] memory _targetOptions = new uint8[](count);
    uint256[] memory values = new uint256[](count);
    bytes[] memory calldatas = new bytes[](count);
    uint256[] memory gasAmounts = new uint256[](count);

    for (uint8 i = 0; i < count; i++) {
      _targetOptions[i] = uint8(_bound(uint256(keccak256(abi.encodePacked("targetOptions[i]", i))), 0, 4));
      values[i] = uint256(keccak256(abi.encodePacked("values[i]", i)));
      calldatas[i] = abi.encodePacked("calldatas[i]", i);
      gasAmounts[i] = uint256(keccak256(abi.encodePacked("gasAmounts[i]", i)));
    }

    GlobalProposal.TargetOption[] memory targetOptions;
    assembly {
      targetOptions := _targetOptions
    }

    GlobalProposal.GlobalProposalDetail memory proposal = GlobalProposal.GlobalProposalDetail({
      nonce: nonce,
      expiryTimestamp: expiryTimestamp,
      executor: executor,
      targetOptions: targetOptions,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
    bytes32 actual = GlobalProposal.hash(proposal);
    bytes32 expected = hash(proposal);

    assertEq(actual, expected, "hash mismatch");
  }

  function hash(Proposal.ProposalDetail memory proposal) private pure returns (bytes32) {
    bytes32[] memory calldatasHashList = new bytes32[](proposal.calldatas.length);
    for (uint256 i; i < calldatasHashList.length; ++i) {
      calldatasHashList[i] = keccak256(proposal.calldatas[i]);
    }

    bytes32 targetsHash = keccak256(abi.encodePacked(proposal.targets));
    bytes32 valuesHash = keccak256(abi.encodePacked(proposal.values));
    bytes32 calldatasHash = keccak256(abi.encodePacked(calldatasHashList));
    bytes32 gasAmountsHash = keccak256(abi.encodePacked(proposal.gasAmounts));

    return keccak256(
      abi.encode(
        TYPE_HASH, proposal.nonce, proposal.chainId, proposal.expiryTimestamp, proposal.executor, targetsHash, valuesHash, calldatasHash, gasAmountsHash
      )
    );
  }

  function hash(GlobalProposal.GlobalProposalDetail memory proposal) private pure returns (bytes32) {
    bytes32[] memory calldatasHashList = new bytes32[](proposal.calldatas.length);
    for (uint256 i; i < calldatasHashList.length; ++i) {
      calldatasHashList[i] = keccak256(proposal.calldatas[i]);
    }

    bytes32 targetsHash = keccak256(abi.encodePacked(proposal.targetOptions));
    bytes32 valuesHash = keccak256(abi.encodePacked(proposal.values));
    bytes32 calldatasHash = keccak256(abi.encodePacked(calldatasHashList));
    bytes32 gasAmountsHash = keccak256(abi.encodePacked(proposal.gasAmounts));

    return keccak256(
      abi.encode(GLOBAL_TYPE_HASH, proposal.nonce, proposal.expiryTimestamp, proposal.executor, targetsHash, valuesHash, calldatasHash, gasAmountsHash)
    );
  }
}
