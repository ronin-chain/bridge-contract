// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IBridgeManager} from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

contract Migration__ChangeGV_StableNode_Config {
  address constant _stableNodeBridgeOperator = address(0x564DcB855Eb360826f27D1Eb9c57cbbe6C76F50F);
  address constant _stableNodeGovernor = address(0x3C583c0c97646a73843aE57b93f33e1995C8DC80);

  function _removeStableNodeGovernorAddress() internal pure returns (bytes memory) {
    address[] memory bridgeOperator = new address[](1);
    bridgeOperator[0] = _stableNodeBridgeOperator;

    // function removeBridgeOperators(
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.removeBridgeOperators, (bridgeOperator));
  }

  function _addStableNodeGovernorAddress() internal pure returns (bytes memory) {
    uint96[] memory voteWeight = new uint96[](1);
    address[] memory governor = new address[](1);
    address[] memory bridgeOperator = new address[](1);

    voteWeight[0] = 100;
    governor[0] = _stableNodeGovernor;
    bridgeOperator[0] = _stableNodeBridgeOperator;

    // function addBridgeOperators(
    //   uint96[] calldata voteWeights,
    //   address[] calldata governors,
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.addBridgeOperators, (voteWeight, governor, bridgeOperator));
  }
}
