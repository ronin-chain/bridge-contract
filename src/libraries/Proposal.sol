// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrInvalidChainId, ErrLengthMismatch } from "../utils/CommonErrors.sol";

library Proposal {
  /**
   * @dev Error thrown when there is insufficient gas to execute a function.
   */
  error ErrInsufficientGas(bytes32 proposalHash);

  /**
   * @dev Error thrown when an invalid expiry timestamp is provided.
   */
  error ErrInvalidExpiryTimestamp();

  /**
   * @dev Error thrown when the proposal reverts when execute the internal call no. `callIndex` with revert message is `revertMsg`.
   */
  error ErrLooseProposalInternallyRevert(uint256 callIndex, bytes revertMsg);

  struct ProposalDetail {
    // Nonce to make sure proposals are executed in order
    uint256 nonce;
    // Value 0: all chain should run this proposal
    // Other values: only specific chain has to execute
    uint256 chainId;
    uint256 expiryTimestamp;
    // The address that execute the proposal after the proposal passes.
    // Leave this address as address(0) to auto-execute by the last valid vote.
    address executor;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    uint256[] gasAmounts;
  }

  // keccak256("ProposalDetail(uint256 nonce,uint256 chainId,uint256 expiryTimestamp,address executor,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 internal constant TYPE_HASH = 0x1b59eeec7c321899dc1e7a5b3d876c9a445dffc6d2f96ba842d7489908fdee12;

  /**
   * @dev Validates the proposal.
   */
  function validate(ProposalDetail memory proposal, uint256 maxExpiryDuration) internal view {
    if (
      !(
        proposal.targets.length > 0 && proposal.targets.length == proposal.values.length && proposal.targets.length == proposal.calldatas.length
          && proposal.targets.length == proposal.gasAmounts.length
      )
    ) {
      revert ErrLengthMismatch(msg.sig);
    }

    if (proposal.expiryTimestamp > block.timestamp + maxExpiryDuration) {
      revert ErrInvalidExpiryTimestamp();
    }
  }

  /**
   * @dev Returns struct hash of the proposal.
   */
  function hash(ProposalDetail memory proposal) internal pure returns (bytes32 digest_) {
    uint256[] memory values = proposal.values;
    address[] memory targets = proposal.targets;
    bytes32[] memory calldataHashList = new bytes32[](proposal.calldatas.length);
    uint256[] memory gasAmounts = proposal.gasAmounts;

    for (uint256 i; i < calldataHashList.length; ++i) {
      calldataHashList[i] = keccak256(proposal.calldatas[i]);
    }

    // return
    //   keccak256(
    //     abi.encode(
    //       TYPE_HASH,
    //       proposal.nonce,
    //       proposal.chainId,
    //       proposal.expiryTimestamp
    //       proposal.executor
    //       targetsHash,
    //       valuesHash,
    //       calldatasHash,
    //       gasAmountsHash
    //     )
    //   );
    // /
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, TYPE_HASH)
      mstore(add(ptr, 0x20), mload(proposal)) // proposal.nonce
      mstore(add(ptr, 0x40), mload(add(proposal, 0x20))) // proposal.chainId
      mstore(add(ptr, 0x60), mload(add(proposal, 0x40))) // proposal.expiryTimestamp
      mstore(add(ptr, 0x80), mload(add(proposal, 0x60))) // proposal.executor

      let arrayHashed
      arrayHashed := keccak256(add(targets, 32), mul(mload(targets), 32)) // targetsHash
      mstore(add(ptr, 0xa0), arrayHashed)
      arrayHashed := keccak256(add(values, 32), mul(mload(values), 32)) // valuesHash
      mstore(add(ptr, 0xc0), arrayHashed)
      arrayHashed := keccak256(add(calldataHashList, 32), mul(mload(calldataHashList), 32)) // calldatasHash
      mstore(add(ptr, 0xe0), arrayHashed)
      arrayHashed := keccak256(add(gasAmounts, 32), mul(mload(gasAmounts), 32)) // gasAmountsHash
      mstore(add(ptr, 0x100), arrayHashed)
      digest_ := keccak256(ptr, 0x120)
    }
  }

  /**
   * @dev Returns whether the proposal is auto-executed on the last valid vote.
   */
  function isAutoExecute(ProposalDetail memory proposal) internal pure returns (bool) {
    return proposal.executor == address(0);
  }

  /**
   * @dev Returns whether the proposal is executable for the current chain.
   *
   * @notice Does not check whether the call result is successful or not. Please use `execute` instead.
   *
   */
  function executable(ProposalDetail memory proposal) internal view returns (bool result) {
    return proposal.chainId == 0 || proposal.chainId == block.chainid;
  }

  /**
   * @dev Executes the proposal.
   */
  function execute(ProposalDetail memory proposal) internal returns (bool[] memory successCalls, bytes[] memory returnDatas) {
    if (!executable(proposal)) revert ErrInvalidChainId(msg.sig, proposal.chainId, block.chainid);

    successCalls = new bool[](proposal.targets.length);
    returnDatas = new bytes[](proposal.targets.length);
    for (uint256 i = 0; i < proposal.targets.length; ++i) {
      if (gasleft() <= proposal.gasAmounts[i]) revert ErrInsufficientGas(hash(proposal));

      (successCalls[i], returnDatas[i]) = proposal.targets[i].call{ value: proposal.values[i], gas: proposal.gasAmounts[i] }(proposal.calldatas[i]);

      if (!successCalls[i]) {
        revert ErrLooseProposalInternallyRevert(i, returnDatas[i]);
      }
    }
  }
}
