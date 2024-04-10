// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

contract SLPDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockERC20Param memory param = _arguments();

    args = abi.encode(param.name, param.symbol);
  }

  function _arguments() internal virtual returns (ISharedArgument.MockERC20Param memory) {
    return config.sharedArguments().slp;
  }

  function _getContract() internal pure returns (Contract) {
    return Contract.SLP;
  }

  function run() public virtual returns (MockSLP) {
    return MockSLP(_deployImmutable(_getContract().key()));
  }
}
