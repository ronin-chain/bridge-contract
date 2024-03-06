// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WETHVault } from "@ronin/contracts/extensions/WETHVault.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";


contract MainchainWethVaultDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.WETHVaultParam memory param = config.sharedArguments().mainchainWethVault;

    args = abi.encode(
      param.weth,
      param.owner
    );
  }

  function run() public virtual returns (WETHVault) {
    return WETHVault(_deployImmutable(Contract.MainchainWETHVault.key()));
  }
}
