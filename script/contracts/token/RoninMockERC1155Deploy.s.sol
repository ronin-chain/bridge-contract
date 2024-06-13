pragma solidity ^0.8.19;

import { RoninMockERC1155 } from "@ronin/contracts/mocks/token/RoninMockERC1155.sol";

import { Contract } from "../../utils/Contract.sol";
import { ISharedArgument } from "../../interfaces/ISharedArgument.sol";
import { Migration } from "../../Migration.s.sol";

contract RoninMockERC1155Deploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.RoninMockERC1155Param memory param = config.sharedArguments().roninMockErc1155;

    args = abi.encode(param.defaultAdmin, param.uri, param.name, param.symbol);
  }

  function run() public virtual returns (RoninMockERC1155) {
    return RoninMockERC1155(_deployImmutable(Contract.RoninMockERC1155.key()));
  }
}
