// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MockERC721 } from "@ronin/contracts/mocks/token/MockERC721.sol";
import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

contract MockERC721Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.MockERC721Param memory param = config.sharedArguments().mockErc721;

    args = abi.encode(param.name, param.symbol);
  }

  function run() public virtual returns (MockERC721) {
    return MockERC721(_deployImmutable(Contract.MockERC721.key()));
  }
}
