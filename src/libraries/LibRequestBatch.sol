// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMainchainGatewayV3.sol";
import { TokenInfoBatch } from "./LibTokenInfoBatch.sol";

struct RequestBatch {
  address recipient;
  address tokenAddr;
  TokenInfoBatch info;
}

library LibRequestBatch {
  function forwardRequestToGatewayERC721(RequestBatch memory req, IMainchainGatewayV3 mainchainGateway) internal {
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

  function forwardRequestToGatewayERC1155(RequestBatch memory req, IMainchainGatewayV3 mainchainGateway) internal {
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
