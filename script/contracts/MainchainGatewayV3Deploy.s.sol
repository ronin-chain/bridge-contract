// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { IWETH } from "src/interfaces/IWETH.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MainchainGatewayV3Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MainchainGatewayV3Param memory param = config.sharedArguments().mainchainGatewayV3;

    args = abi.encodeCall(
      MainchainGatewayV3.initialize,
      (
        param.roleSetter,
        IWETH(param.wrappedToken),
        param.roninChainId,
        param.numerator,
        param.highTierVWNumerator,
        param.denominator,
        param.addresses,
        param.thresholds,
        param.standards
      )
    );
  }

  function run() public virtual returns (MainchainGatewayV3) {
    return MainchainGatewayV3(_deployProxy(Contract.MainchainGatewayV3.key()));
  }
}
