// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WBTC } from "@ronin/contracts/tokens/erc20/WBTC.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";

import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract WBTCDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory) {
    address gateway = loadContract(Contract.RoninGatewayV3.key());
    address pauseEnforcer = loadContract(Contract.RoninPauseEnforcer.key());

    return abi.encode(gateway, pauseEnforcer);
  }

  function run() public virtual returns (WBTC instance) {
    instance = WBTC(_deployImmutable(Contract.WBTC.key()));
    assertEq(instance.decimals(), 8, "WBTC: invalid decimals");
  }
}
