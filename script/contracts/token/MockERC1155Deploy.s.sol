// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockERC1155 } from "@ronin/contracts/mocks/token/MockERC1155.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

contract MockERC1155Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockERC1155Param memory param = config.sharedArguments().mockErc1155;

    args = abi.encode(param.defaultAdmin, param.uri, param.name, param.symbol);
  }

  function run() public virtual returns (MockERC1155) {
    return MockERC1155(_deployImmutable(Contract.MockERC1155.key()));
  }
}
