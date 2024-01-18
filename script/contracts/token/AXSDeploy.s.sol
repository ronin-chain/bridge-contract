// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { MockERC20Deploy } from "./MockERC20Deploy.s.sol";

contract AXSDeploy is MockERC20Deploy {
  function _arguments() internal virtual override returns (ISharedArgument.MockERC20Param memory) {
    return config.sharedArguments().axs;
  }

  function _getContract() internal virtual override returns (Contract) {
    return Contract.AXS;
  }
}
