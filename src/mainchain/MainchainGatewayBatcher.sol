// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libraries/LibTokenInfoBatch.sol";
import "./MainchainGatewayV3.sol";

contract MainchainGatewayBatcher is Initializable {
  MainchainGatewayV3 internal _mainchainGateway;

  constructor() {
    _disableInitializers();
  }

  struct RequestBatch {
    address recipient;
    address tokenAddr;
    TokenInfoBatch info;
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
    _validateRequestBatchERC721(request);
    _handleAssetInBatchERC721(request);

    IERC721(request.tokenAddr).setApprovalForAll(address(_mainchainGateway), true);
    _forwardRequestToGatewayERC721(request);
  }

  function _validateRequestBatchERC721(RequestBatch memory request) internal pure {
    if (request.info.erc != TokenStandard.ERC721) {
      revert ErrUnsupportedToken();
    }

    if (
      request.info.ids.length == 0 // Request must contain valid array of  ids
        || request.info.quantities.length != 0 // Quantity of each ERC721 alway is 1, no input to save gas
    ) {
      revert ErrInvalidRequest();
    }
  }

  function _handleAssetInBatchERC721(RequestBatch memory request) internal returns (bool success) {
    success = _tryTransferFromERC721Loop(request.tokenAddr, msg.sender, address(this), request.info.ids);
    if (!success) {
      revert("Transfer Failed");
    }
  }

  /**
   * @dev Transfers ERC721 token in a loop and returns the result.
   *
   * If there is fail when transfer one `id`, the loop will break early to save gas.
   * Consumer of this method should revert the transaction if receive `false` success status.
   */
  function _tryTransferFromERC721Loop(address token, address from, address to, uint256[] memory ids)
    private
    returns (bool success)
  {
    for (uint256 i; i < ids.length; ++i) {
      if (!_tryTransferFromERC721(token, from, to, ids[i])) {
        return false; // Break early if send fails
      }
    }

    return true;
  }

  /**
   * @dev Transfers ERC721 token and returns the result.
   */
  function _tryTransferFromERC721(address token, address from, address to, uint256 id) private returns (bool success) {
    (success,) = token.call(abi.encodeWithSelector(IERC721.transferFrom.selector, from, to, id));
  }

  function _forwardRequestToGatewayERC721(RequestBatch memory req) internal {
    for (uint256 i; i < req.info.ids.length; i++) {
      _mainchainGateway.requestDepositFor(
        Transfer.Request({
          recipientAddr: req.recipient,
          tokenAddr: req.tokenAddr,
          info: TokenInfo({ erc: req.info.erc, id: req.info.ids[i], quantity: 0 })
        })
      );
    }
  }
}
