// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { GeneralConfig } from "./GeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { Network } from "./utils/Network.sol";

contract Migration is BaseMigration {
  ISharedArgument public constant config = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == Network.Goerli.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.RoninTestnet.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.Local.key()) {
      param.test.proxyAdmin = makeAddr("proxy-admin");
    } else {
      revert("Migration: Network Unknown Shared Parameters Unimplemented!");
    }

    rawArgs = abi.encode(param);
  }
}
