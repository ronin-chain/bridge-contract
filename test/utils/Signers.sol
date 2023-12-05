// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StdCheats} from "forge-std/StdCheats.sol";

contract SignerUtils is StdCheats {
  uint256 public constant ACCOUNT_SIGNER = uint256(keccak256("@ronin-bridge-contract.signer.index"));
  uint256 internal _accountNonce;

  function _getSigners(uint256 num) internal returns (Account[] memory accounts) {
    uint256 startIdx = _accountNonce;
    uint256 endIdx = _accountNonce += num;
    accounts = new Account[](num);

    for (uint256 i = startIdx; i < endIdx; i++) {
      accounts[i] = makeAccount(string(abi.encodePacked(ACCOUNT_SIGNER, i)));
    }
  }
}
