// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockDiscardEther {
  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  function _fallback() internal pure {
    revert("Not receive ether");
  }
}
