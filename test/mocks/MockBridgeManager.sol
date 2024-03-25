// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

contract MockBridgeManager is IBridgeManager {
  mapping(address => bool) private _governors;
  mapping(address => bool) private _operators;
  mapping(address => uint96) private _weights;
  address[] private _operatorList;

  function DOMAIN_SEPARATOR() external view returns (bytes32) { }

  function cheat_setOperators(address[] calldata operators) external {
    for (uint i; i < _operatorList.length; i++) {
      address iOperator = _operatorList[i];
      delete _operators[iOperator];
      delete _governors[iOperator];
      delete _weights[iOperator];
    }
    delete _operatorList;

    for (uint i; i < operators.length; i++) {
      address iOperator = operators[i];
      _operatorList.push(iOperator);
      _operators[iOperator] = true;
      _governors[iOperator] = true;
      _weights[iOperator] = 100;
    }
  }

  function addBridgeOperators(uint96[] calldata weights, address[] calldata governors, address[] calldata operators) external returns (bool[] memory addeds) {
    for (uint i; i < weights.length; i++) {
      _governors[governors[i]] = true;
      _operators[operators[i]] = true;
      _weights[governors[i]] = weights[i];
      _weights[operators[i]] = weights[i];
      addeds[i] = true;
    }
  }

  function addOperator(uint96 weight, address governor, address operator) external {
    _governors[governor] = true;
    _operators[operator] = true;
    _weights[governor] = weight;
    _weights[operator] = weight;
  }

  function setMinRequiredGovernor(uint min) external { }

  function getBridgeOperatorOf(address[] calldata gorvernors) external view returns (address[] memory bridgeOperators_) { }

  function getOperatorOf(address governor) external view returns (address operator) { }

  function getBridgeOperatorWeight(address bridgeOperator) external view returns (uint96 weight) { }

  function getBridgeOperators() external view returns (address[] memory) {
    return _operatorList;
  }

  function getFullBridgeOperatorInfos() external view returns (address[] memory governors, address[] memory bridgeOperators, uint96[] memory weights) { }

  function getGovernorWeight(address governor) external view returns (uint96) { }

  function getGovernorWeights(address[] calldata governors) external view returns (uint96[] memory weights) { }

  function getGovernors() external view returns (address[] memory) { }

  function getGovernorsOf(address[] calldata bridgeOperators) external view returns (address[] memory governors) { }

  function getGovernorOf(address operator) external view returns (address governor) { }

  function getTotalWeight() external view returns (uint256) { }

  function isBridgeOperator(address addr) external view returns (bool) {
    return _weights[addr] > 0;
  }

  function removeBridgeOperators(address[] calldata bridgeOperators) external returns (bool[] memory removeds) { }

  function sumGovernorsWeight(address[] calldata governors) external view returns (uint256 sum) { }

  function totalBridgeOperator() external view returns (uint256) { }

  function updateBridgeOperator(address currOperator, address newOperator) external { }
}
