// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../libraries/LibRequestBatch.sol";
import "../libraries/LibTokenInfoBatch.sol";
import "./MainchainGatewayV3.sol";

contract MainchainGatewayBatcher is Initializable, ERC1155Holder {
  using LibRequestBatch for RequestBatch;
  using LibTokenInfoBatch for TokenInfoBatch;

  MainchainGatewayV3 internal _mainchainGateway;

  constructor() {
    _disableInitializers();
  }

  function initialize(MainchainGatewayV3 gateway) external initializer {
    _mainchainGateway = gateway;
  }

  event BatchDepositRequested(address indexed requested);

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
    // Dispatch the corresponding internal methods for each type of ERC
    (
      function (TokenInfoBatch memory) pure returns (bool) fCheck,
      function (TokenInfoBatch memory, address, address) returns (bool) fHandleAssetIn,
      function (RequestBatch memory, IMainchainGatewayV3) fForwardRequestToGateway
    ) = _dispatcher(request.info.erc);

    // Revert if validate fails
    request.info.validate(fCheck);

    // Revert if cannot transfer all tokens to this Batcher
    request.info.handleAssetIn(msg.sender, request.tokenAddr, fHandleAssetIn);

    // Approve all tokens from this Batcher to the actual Gateway
    IERC721(request.tokenAddr).setApprovalForAll(address(_mainchainGateway), true);

    // Loop over all token ids and make a deposit request for each
    fForwardRequestToGateway(request, _mainchainGateway);

    emit BatchDepositRequested(msg.sender);
  }

  function _dispatcher(TokenStandard erc)
    private
    pure
    returns (
      function (TokenInfoBatch memory) pure returns (bool) fValidate,
      function (TokenInfoBatch memory, address, address) returns (bool) fHandleAsset,
      function (RequestBatch memory, IMainchainGatewayV3) fForwardRequestToGateway
    )
  {
    if (erc == TokenStandard.ERC721) {
      return (
        LibTokenInfoBatch.checkERC721Batch,
        LibTokenInfoBatch.tryHandleAssetInERC721,
        LibRequestBatch.forwardRequestToGatewayERC721
      );
    }

    if (erc == TokenStandard.ERC1155) {
      return (
        LibTokenInfoBatch.checkERC1155Batch,
        LibTokenInfoBatch.tryHandleAssetInERC1155,
        LibRequestBatch.forwardRequestToGatewayERC1155
      );
    }

    revert ErrUnsupportedStandard();
  }
}
