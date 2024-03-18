// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMainchainGatewayV3.sol";
import { TokenInfoBatch, ErrUnsupportedStandard } from "./LibTokenInfoBatch.sol";

struct RequestBatch {
  address recipient;
  address tokenAddr;
  TokenInfoBatch info;
}

library LibRequestBatch {
  function forwardRequestToGateway(RequestBatch memory req, IMainchainGatewayV3 mainchainGateway) internal {
    if (req.info.erc == TokenStandard.ERC721) {
      _forwardRequestToGatewayERC721(req, mainchainGateway);
    } else if (req.info.erc == TokenStandard.ERC1155) {
      _forwardRequestToGatewayERC1155(req, mainchainGateway);
    } else {
      revert ErrUnsupportedStandard();
    }
  }

  function _forwardRequestToGatewayERC721(RequestBatch memory req, IMainchainGatewayV3 mainchainGateway) internal {
    for (uint256 i; i < req.info.ids.length; i++) {
      mainchainGateway.requestDepositFor(
        Transfer.Request({
          recipientAddr: req.recipient,
          tokenAddr: req.tokenAddr,
          info: TokenInfo({ erc: req.info.erc, id: req.info.ids[i], quantity: 0 })
        })
      );
    }
  }

  function _forwardRequestToGatewayERC1155(RequestBatch memory req, IMainchainGatewayV3 mainchainGateway) internal {
    for (uint256 i; i < req.info.ids.length; i++) {
      mainchainGateway.requestDepositFor(
        Transfer.Request({
          recipientAddr: req.recipient,
          tokenAddr: req.tokenAddr,
          info: TokenInfo({ erc: req.info.erc, id: req.info.ids[i], quantity: req.info.quantities[i] })
        })
      );
    }
  }
}
