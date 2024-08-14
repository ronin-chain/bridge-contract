// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainGatewayV3Deploy is Migration {
  function run() public virtual returns (IMainchainGatewayV3) {
    return IMainchainGatewayV3(_deployProxy(Contract.MainchainGatewayV3.key(), EMPTY_ARGS));
  }
}
