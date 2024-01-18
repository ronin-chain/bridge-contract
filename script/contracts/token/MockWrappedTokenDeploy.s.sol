// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockWrappedToken } from "@ronin/contracts/mocks/token/MockWrappedToken.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

abstract contract MockWrappedTokenDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockWrappedTokenParam memory param = _arguments();

    args = abi.encode(param.name, param.symbol);
  }

  function _arguments() internal virtual returns (ISharedArgument.MockWrappedTokenParam memory);
  function _getContract() internal virtual returns (Contract);

  function run() public virtual returns (MockWrappedToken) {
    return MockWrappedToken(_deployImmutable(_getContract().key()));
  }
}
