// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Proposal.sol";

library GlobalProposal {
  /**
   * @dev Error thrown when attempting to interact with an unsupported target.
   */
  error ErrUnsupportedTarget(bytes32 proposalHash, uint256 targetNumber);

  enum TargetOption {
    /* 0 */ BridgeManager,
    /* 1 */ GatewayContract,
    /* 2 */ BridgeReward,
    /* 3 */ BridgeSlash,
    /* 4 */ BridgeTracking
  }

  struct GlobalProposalDetail {
    // Nonce to make sure proposals are executed in order
    uint256 nonce;
    uint256 expiryTimestamp;
    address executor;
    TargetOption[] targetOptions;
    uint256[] values;
    bytes[] calldatas;
    uint256[] gasAmounts;
  }

  // keccak256("GlobalProposalDetail(uint256 nonce,uint256 expiryTimestamp,address executor,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
  bytes32 internal constant TYPE_HASH = 0xde480f0c53a3651c08fbab1dffbc45fe574f31188827fe52cb9035da9fe57e4a;

  /**
   * @dev Returns struct hash of the proposal.
   */
  function hash(GlobalProposalDetail memory self) internal pure returns (bytes32 digest_) {
    uint256[] memory values = self.values;
    TargetOption[] memory targets = self.targetOptions;
    bytes32[] memory calldataHashList = new bytes32[](self.calldatas.length);
    uint256[] memory gasAmounts = self.gasAmounts;

    for (uint256 i; i < calldataHashList.length;) {
      calldataHashList[i] = keccak256(self.calldatas[i]);

      unchecked {
        ++i;
      }
    }

    /*
     * return
     *   keccak256(
     *     abi.encode(
     *       TYPE_HASH,
     *       proposal.nonce,
     *       proposal.expiryTimestamp,
     *       proposal.executor,
     *       targetsHash,
     *       valuesHash,
     *       calldatasHash,
     *       gasAmountsHash
     *     )
     *   );
     */
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, TYPE_HASH)
      mstore(add(ptr, 0x20), mload(self)) // proposal.nonce
      mstore(add(ptr, 0x40), mload(add(self, 0x20))) // proposal.expiryTimestamp
      mstore(add(ptr, 0x60), mload(add(self, 0x40))) // proposal.executor

      let arrayHashed
      arrayHashed := keccak256(add(targets, 32), mul(mload(targets), 32)) // targetsHash
      mstore(add(ptr, 0x80), arrayHashed)
      arrayHashed := keccak256(add(values, 32), mul(mload(values), 32)) // valuesHash
      mstore(add(ptr, 0xa0), arrayHashed)
      arrayHashed := keccak256(add(calldataHashList, 32), mul(mload(calldataHashList), 32)) // calldatasHash
      mstore(add(ptr, 0xc0), arrayHashed)
      arrayHashed := keccak256(add(gasAmounts, 32), mul(mload(gasAmounts), 32)) // gasAmountsHash
      mstore(add(ptr, 0xe0), arrayHashed)
      digest_ := keccak256(ptr, 0x100)
    }
  }

  /**
   * @dev Converts into the normal proposal.
   */
  function intoProposalDetail(GlobalProposalDetail memory self, address[] memory targets) internal pure returns (Proposal.ProposalDetail memory detail_) {
    detail_.nonce = self.nonce;
    detail_.chainId = 0;
    detail_.expiryTimestamp = self.expiryTimestamp;
    detail_.executor = self.executor;

    detail_.targets = new address[](self.targetOptions.length);
    detail_.values = self.values;
    detail_.calldatas = self.calldatas;
    detail_.gasAmounts = self.gasAmounts;

    for (uint256 i; i < self.targetOptions.length; ++i) {
      detail_.targets[i] = targets[i];
    }
  }
}
