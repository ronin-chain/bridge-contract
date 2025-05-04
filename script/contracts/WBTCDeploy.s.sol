// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { WBTC } from "@ronin/contracts/tokens/erc20/WBTC.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";

contract WBTCDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory) {
    address admin = 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a;
    address minter = admin;
    address pauser = admin;
    address burner = admin;

    return abi.encodeCall(WBTC.initialize, (admin, minter, burner, pauser));
  }

  function _getProxyAdmin() internal virtual override returns (address payable) {
    // ronin-mainnet: SC Multisig
    return payable(0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a);
  }

  function run() public virtual returns (WBTC instance) {
    instance = WBTC(_deployProxy(Contract.WBTC.key()));

    assertEq(instance.decimals(), 8, "WBTC: invalid decimals");
    assertEq(instance.symbol(), "WBTC", "WBTC: invalid symbol");
    assertEq(instance.name(), "Wrapped Bitcoin", "WBTC: invalid name");
  }
}
