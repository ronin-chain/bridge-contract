// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WethMediator } from "@ronin/contracts/extensions/WethMediator.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";


contract MainchainWethMediatorDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.WethMediatorParam memory param = config.sharedArguments().mainchainWethMediator;

    args = abi.encode(
      param.weth,
      param.owner
    );
  }

  function run() public virtual returns (WethMediator) {
    return WethMediator(_deployImmutable(Contract.MainchainWethMediator.key()));
  }
}
