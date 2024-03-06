// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IWETH.sol";

contract WETHVault is Ownable {
  IWETH public weth;

  error ErrInsufficientBalance();
  error ErrExternalCallFailed(address sender, bytes4 sig);

  constructor(address weth_, address owner_) {
    weth = IWETH(weth_);

    if (owner_ != address(0)) {
      _transferOwnership(owner_);
    }
  }

  fallback() external payable { }
  receive() external payable { }

  function transferToVault(uint val) external {
    weth.withdraw(val);
  }

  function withdrawToOwner(uint val) external onlyOwner {
    if (val > address(this).balance) {
      revert ErrInsufficientBalance();
    }

    (bool success,) = payable(msg.sender).call{ value: val }("");
    if (!success) {
      revert ErrExternalCallFailed(msg.sender, msg.sig);
    }
  }

  function setWeth(address weth_) external onlyOwner {
    weth = IWETH(weth_);
  }
}
