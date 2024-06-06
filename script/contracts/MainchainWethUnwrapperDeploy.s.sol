// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WethUnwrapper } from "@ronin/contracts/extensions/WethUnwrapper.sol";
import { Contract } from "../utils/Contract.sol";
import { WETHDeploy } from "./token/WETHDeploy.s.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainWethUnwrapperDeploy is Migration {
  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.WETH.key(), new WETHDeploy());
  }

  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.WethUnwrapperParam memory param = config.sharedArguments().mainchainWethUnwrapper;

    args = abi.encode(param.weth == address(0x0) ? loadContractOrDeploy(Contract.WETH.key()) : param.weth);
  }

  function run() public virtual returns (WethUnwrapper) {
    return WethUnwrapper(_deployImmutable(Contract.MainchainWethUnwrapper.key()));
  }

  function runWithArgs(bytes memory args) public virtual returns (WethUnwrapper) {
    return WethUnwrapper(_deployImmutable(Contract.MainchainWethUnwrapper.key(), args));
  }
}
