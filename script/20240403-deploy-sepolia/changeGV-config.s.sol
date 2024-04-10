// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

contract DeploySepolia__ChangeGV_Config {
  function _removeInitOperator() internal pure returns (bytes memory) {
    address[] memory bridgeOperator = new address[](1);
    bridgeOperator[0] = 0xbA8E32D874948dF4Cbe72284De91CC4968293BCe;

    // function removeBridgeOperators(
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.removeBridgeOperators, (bridgeOperator));
  }

  function _addTestnetOperators() internal pure returns (bytes memory) {
    uint96[] memory voteWeights = new uint96[](4);
    address[] memory governors = new address[](4); // 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa,0xb033ba62EC622dC54D0ABFE0254e79692147CA26,0x087D08e3ba42e64E3948962dd1371F906D1278b9,0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F
    address[] memory bridgeOperators = new address[](4); // 0x2e82D2b56f858f79DeeF11B160bFC4631873da2B,0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb,0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c,0xcc5Fc5B6c8595F56306Da736F6CD02eD9141C84A

    voteWeights[0] = 100;
    voteWeights[1] = 100;
    voteWeights[2] = 100;
    voteWeights[3] = 100;

    governors[0] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[1] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[2] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[3] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    bridgeOperators[0] = 0x2e82D2b56f858f79DeeF11B160bFC4631873da2B;
    bridgeOperators[1] = 0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb;
    bridgeOperators[2] = 0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c;
    bridgeOperators[3] = 0xcc5Fc5B6c8595F56306Da736F6CD02eD9141C84A;

    // function addBridgeOperators(
    //   uint96[] calldata voteWeights,
    //   address[] calldata governors,
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.addBridgeOperators, (voteWeights, governors, bridgeOperators));
  }
}
