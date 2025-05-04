// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninGatewayV3 } from "script/interfaces/IRoninGatewayV3.sol";
import { IWETH } from "src/interfaces/IWETH.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract RoninGatewayV3Deploy is Migration {
  function run() public virtual returns (IRoninGatewayV3) {
    return IRoninGatewayV3(_deployProxy(Contract.RoninGatewayV3.key(), EMPTY_ARGS));
  }
}
