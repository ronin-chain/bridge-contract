// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WBTC_Sepolia } from "@ronin/contracts/tokens/erc20/WBTC_Sepolia.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Migration } from "../Migration.s.sol";

import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract WBTCSepolia_Deploy is Migration {
  function run() public virtual onlyOn(Network.Sepolia.key()) returns (WBTC_Sepolia instance) {
    instance = WBTC_Sepolia(_deployImmutable(Contract.WBTC.key()));
    assertEq(instance.decimals(), 8, "WBTC: invalid decimals");
  }
}
