// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { MockWrappedTokenDeploy } from "./MockWrappedTokenDeploy.s.sol";

contract WETHDeploy is MockWrappedTokenDeploy {
  function _arguments() internal virtual override returns (ISharedArgument.MockWrappedTokenParam memory) {
    return config.sharedArguments().weth;
  }

  function _getContract() internal virtual override returns (Contract) {
    return Contract.WETH;
  }
}
