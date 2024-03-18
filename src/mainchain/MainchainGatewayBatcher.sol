// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libraries/LibRequestBatch.sol";
import "../libraries/LibTokenInfoBatch.sol";
import "./MainchainGatewayV3.sol";

contract MainchainGatewayBatcher is Initializable {
  using LibRequestBatch for RequestBatch;
  using LibTokenInfoBatch for TokenInfoBatch;

  MainchainGatewayV3 internal _mainchainGateway;

  constructor() {
    _disableInitializers();
  }

  function initialize(MainchainGatewayV3 gateway) external initializer {
    _mainchainGateway = gateway;
  }

  /**
   * @notice Batch transfer token from user to this Batcher, then sequentially request deposit for to gateway on behalf of user.
   *
   * @dev This method is a workaround that mostly reduce UX for user when deposit token in batch, meanwhile require zero change on the current Gateway code.
   *
   * Logic:
   * - Validate the RequestBatch
   * - `transferFrom` all tokens to this Batcher from user
   * - `requestDepositFor` in the loop for each token, in which:
   *    - each token will be `transferFrom` this Batcher to the Gateway
   *    - `requester` field in the `Request` struct is this Batcher
   *
   * Requirement:
   * - User must `approveAll` tokens for this Batcher
   * - Emit an event that include information of the {RequestBatch}
   */
  function requestDepositForBatch(RequestBatch calldata request) external {
    request.info.validate();
    request.info.handleAssetIn(msg.sender, request.tokenAddr);

    IERC721(request.tokenAddr).setApprovalForAll(address(_mainchainGateway), true);
    request.forwardRequestToGateway(_mainchainGateway);
  }
}
