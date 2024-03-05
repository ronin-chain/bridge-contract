// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

abstract contract MockERC20Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockERC20Param memory param = _arguments();

    args = abi.encode(param.name, param.symbol);
  }

  function _arguments() internal virtual returns (ISharedArgument.MockERC20Param memory);
  function _getContract() internal virtual returns (Contract);

  function run() public virtual returns (MockERC20) {
    return MockERC20(_deployImmutable(_getContract().key()));
  }
}
