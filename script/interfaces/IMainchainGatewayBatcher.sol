// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RequestBatch } from "@ronin/contracts/libraries/LibRequestBatch.sol";
import { TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { TokenInfoBatch } from "@ronin/contracts/libraries/LibTokenInfoBatch.sol";

interface IMainchainGatewayBatcher {
  error ErrInvalidInfoWithStandard(TokenStandard);
  error ErrTokenBatchCouldNotTransferFrom(TokenInfoBatch tokenInfo, address from, address to, address token);
  error ErrUnsupportedStandard();

  event BatchDepositRequested(address indexed requested);
  event Initialized(uint8 version);

  function initialize(address gateway) external;
  function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) external returns (bytes4);
  function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
  function requestDepositForBatch(RequestBatch memory request) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
