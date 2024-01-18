// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { IWETH } from "src/interfaces/IWETH.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract RoninGatewayV3Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.RoninGatewayV3Param memory param = config.sharedArguments().roninGatewayV3;

    args = abi.encodeCall(
      RoninGatewayV3.initialize,
      (
        param.roleSetter,
        param.numerator,
        param.denominator,
        param.trustedNumerator,
        param.trustedDenominator,
        param.withdrawalMigrators,
        param.packedAddresses,
        param.packedNumbers,
        param.standards
      )
    );
  }

  function run() public virtual returns (RoninGatewayV3) {
    return RoninGatewayV3(_deployProxy(Contract.RoninGatewayV3.key()));
  }
}
