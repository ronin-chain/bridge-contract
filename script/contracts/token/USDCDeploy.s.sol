// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockUSDC } from "@ronin/contracts/mocks/token/MockUSDC.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

contract USDCDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockERC20Param memory param = _arguments();

    args = abi.encode(param.name, param.symbol);
  }

  function _arguments() internal virtual returns (ISharedArgument.MockERC20Param memory) {
    return config.sharedArguments().usdc;
  }

  function _getContract() internal returns (Contract) {
    return Contract.USDC;
  }

  function run() public virtual returns (MockUSDC) {
    return MockUSDC(_deployImmutable(_getContract().key()));
  }
}
