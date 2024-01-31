// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

contract Migration__Update_AxieChat_Config {
  address constant _axieChatBridgeOperator = address(0x772112C7e5dD4ed663e844e79d77c1569a2E88ce);
  address constant _axieChatGovernor = address(0x5832C3219c1dA998e828E1a2406B73dbFC02a70C);

  function _removeAxieChatGovernorAddress() pure internal returns (bytes memory) {
    address[] memory bridgeOperator = new address[](1);
    bridgeOperator[0] = _axieChatBridgeOperator;

    // function removeBridgeOperators(
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.removeBridgeOperators, (
      bridgeOperator
    ));
  }

  function _addAxieChatGovernorAddress() pure internal returns (bytes memory) {
    uint96[] memory voteWeight = new uint96[](1);
    address[] memory governor = new address[](1);
    address[] memory bridgeOperator = new address[](1);

    voteWeight[0] = 100;
    governor[0] = _axieChatGovernor;
    bridgeOperator[0] = _axieChatBridgeOperator;

    // function addBridgeOperators(
    //   uint96[] calldata voteWeights,
    //   address[] calldata governors,
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.addBridgeOperators, (
      voteWeight,
      governor,
      bridgeOperator
    ));
  }
}