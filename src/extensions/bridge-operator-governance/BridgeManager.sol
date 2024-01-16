// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IBridgeManagerCallback, BridgeManagerCallbackRegister } from "./BridgeManagerCallbackRegister.sol";
import { IHasContracts, HasContracts } from "../../extensions/collections/HasContracts.sol";

import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { AddressArrayUtils } from "../../libraries/AddressArrayUtils.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { RoleAccess } from "../../utils/RoleAccess.sol";
import { TUint256Slot } from "../../types/Types.sol";
import "../../utils/CommonErrors.sol";
import "./BridgeManagerQuorum.sol";

abstract contract BridgeManager is IBridgeManager, HasContracts, BridgeManagerQuorum, BridgeManagerCallbackRegister {
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  struct BridgeManagerStorage {
    /// @notice List of the governors.
    /// @dev We do not use EnumerableSet here to maintain identical order of `governors` and `operators`. If `.contains` is needed, use the corresponding weight mapping.
    address[] _governors;
    address[] _operators;
    /// @dev Mapping from address to the governor weight
    mapping(address governor => uint96 weight) _governorWeight;
    /// @dev Mapping from address to the operator weight. This must always be identical `_governorWeight`.
    mapping(address operator => uint96 weight) _operatorWeight;
    /// @dev Total weight of all governors / operators.
    uint256 _totalWeight;
  }

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.BridgeManagerStorageLocation")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_BridgeManagerStorageLocation = 0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300;

  /**
   * @inheritdoc IBridgeManager
   */
  bytes32 public immutable DOMAIN_SEPARATOR;

  function _getBridgeManagerStorage() private pure returns (BridgeManagerStorage storage $) {
    assembly {
      $.slot := $$_BridgeManagerStorageLocation
    }
  }

  modifier onlyGovernor() virtual {
    _requireGovernor(msg.sender);
    _;
  }

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights
  ) payable BridgeManagerQuorum(num, denom) BridgeManagerCallbackRegister(callbackRegisters) {
    _setContract(ContractType.BRIDGE, bridgeContract);

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", roninChainId)) // salt
      )
    );

    _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  // ===================== CONFIG ========================

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(ContractType contractType, address addr) external override onlySelfCall {
    _requireHasCode(addr);
    _setContract(contractType, addr);
  }

  /**
   * @dev Internal function to require that the caller has governor role access.
   */
  function _requireGovernor(address addr) internal view {
    if (_getGovernorWeight(addr) == 0) {
      revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    }
  }

  // ===================== WEIGHTS METHOD ========================

  /**
   * @inheritdoc IBridgeManager
   */
  function getTotalWeight() public view returns (uint256) {
    return _totalWeight();
  }

  function _totalWeight() internal view override returns (uint256) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._totalWeight;
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorWeights(address[] calldata governors) external view returns (uint96[] memory weights) {
    weights = _getGovernorWeights(governors);
  }

  /**
   * @dev Internal function to get the vote weights of a given array of governors.
   */
  function _getGovernorWeights(address[] memory governors) internal view returns (uint96[] memory weights) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    uint256 length = governors.length;
    weights = new uint96[](length);

    for (uint256 i; i < length; i++) {
      weights[i] = $._governorWeight[governors[i]];
    }
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorWeight(address governor) external view returns (uint96 weight) {
    weight = _getGovernorWeight(governor);
  }

  /**
   * @dev Internal function to retrieve the vote weight of a specific governor.
   */
  function _getGovernorWeight(address governor) internal view returns (uint96) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._governorWeight[governor];
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function sumGovernorsWeight(address[] calldata governors) external view nonDuplicate(governors) returns (uint256 sum) {
    sum = _sumGovernorsWeight(governors);
  }

  /**
   * @dev Internal function to calculate the sum of vote weights for a given array of governors.
   * @param governors The non-duplicated input.
   */
  function _sumGovernorsWeight(address[] memory governors) internal view nonDuplicate(governors) returns (uint256 sum) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    for (uint256 i; i < governors.length; i++) {
      sum += $._governorWeight[governors[i]];
    }
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeOperatorWeight(address bridgeOperator) external view returns (uint96 weight) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    return $._operatorWeight[bridgeOperator];
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    (uint256 numerator, uint256 denominator) = getThreshold();
    return (numerator * $._totalWeight + denominator - 1) / denominator;
  }

  // ===================== MANAGER CRUD ========================

  /**
   * @inheritdoc IBridgeManager
   */
  function addBridgeOperators(
    uint96[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  ) external onlySelfCall returns (bool[] memory addeds) {
    addeds = _addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function removeBridgeOperators(address[] calldata bridgeOperators) external onlySelfCall returns (bool[] memory removeds) {
    removeds = _removeBridgeOperators(bridgeOperators);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function updateBridgeOperator(address currOperator, address newOperator) external onlyGovernor {
    _requireNonZeroAddress(newOperator);

    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    if (currOperator == newOperator || $._governorWeight[newOperator] > 0 || $._operatorWeight[newOperator] > 0) {
      revert ErrBridgeOperatorAlreadyExisted(newOperator);
    }

    // Query the index of the operator in the array
    (address requiredGovernor, uint idx) = _getGovernorOf(currOperator);
    if (requiredGovernor != msg.sender) revert ErrGovernorNotMatch(requiredGovernor, msg.sender);

    // Replace the bridge operator: (1) change in the array, (2) update weight of two addresses, (3) notify register
    $._operators[idx] = newOperator;
    $._operatorWeight[newOperator] = $._operatorWeight[currOperator];
    delete $._operatorWeight[currOperator];

    _notifyRegisters(IBridgeManagerCallback.onBridgeOperatorUpdated.selector, abi.encode(currOperator, newOperator));

    emit BridgeOperatorUpdated(msg.sender, currOperator, newOperator);
  }

  /**
   * @dev Internal function to add bridge operators.
   *
   * This function adds the specified `bridgeOperators` to the bridge operator set and establishes the associated mappings.
   *
   * Requirements:
   * - The caller must have the necessary permission to add bridge operators.
   * - The lengths of `voteWeights`, `governors`, and `bridgeOperators` arrays must be equal.
   *
   * @return addeds An array of boolean values indicating whether each bridge operator was successfully added.
   */
  function _addBridgeOperators(
    uint96[] memory voteWeights,
    address[] memory newGovernors,
    address[] memory newOperators
  ) internal nonDuplicate(newGovernors.extend(newOperators)) returns (bool[] memory addeds) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    uint256 length = newOperators.length;
    if (!(length == voteWeights.length && length == newGovernors.length)) revert ErrLengthMismatch(msg.sig);
    addeds = new bool[](length);

    // simply skip add operations if inputs are empty.
    if (length == 0) return addeds;

    address iGovernor;
    address iOperator;
    uint96 iVoteWeight;
    uint256 accumulatedWeight;

    for (uint256 i; i < length; i++) {
      iGovernor = newGovernors[i];
      iOperator = newOperators[i];
      iVoteWeight = voteWeights[i];

      // Check non-zero inputs
      _requireNonZeroAddress(iGovernor);
      _requireNonZeroAddress(iOperator);
      if (iVoteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);

      // Check not yet added operators
      addeds[i] = ($._governorWeight[iGovernor] + $._governorWeight[iOperator] + $._operatorWeight[iOperator] + $._operatorWeight[iGovernor]) == 0;

      // Only add the valid operator
      if (addeds[i]) {
        // Add governor to list, update governor weight
        $._governors.push(iGovernor);
        $._governorWeight[iGovernor] = iVoteWeight;

        // Add operator to list, update governor weight
        $._operators.push(iOperator);
        $._operatorWeight[iOperator] = iVoteWeight;

        accumulatedWeight += iVoteWeight;
      }
    }

    $._totalWeight += accumulatedWeight;

    _notifyRegisters(IBridgeManagerCallback.onBridgeOperatorsAdded.selector, abi.encode(newOperators, addeds));

    emit BridgeOperatorsAdded(addeds, voteWeights, newGovernors, newOperators);
  }

  /**
   * @dev Internal function to remove bridge operators.
   *
   * This function removes the specified `bridgeOperators` from the bridge operator set and related mappings.
   *
   * Requirements:
   * - The caller must have the necessary permission to remove bridge operators.
   *
   * @param removingOperators An array of addresses representing the bridge operators to be removed.
   * @return removeds An array of boolean values indicating whether each bridge operator was successfully removed.
   */
  function _removeBridgeOperators(address[] memory removingOperators) internal nonDuplicate(removingOperators) returns (bool[] memory removeds) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    uint256 length = removingOperators.length;
    removeds = new bool[](length);

    // simply skip remove operations if inputs are empty.
    if (length == 0) return removeds;

    address iGovernor;
    address iOperator;
    uint256 accumulatedWeight;
    uint idx;

    for (uint256 i; i < length; i++) {
      iOperator = removingOperators[i];

      // Check non-zero inputs
      (iGovernor, idx) = _getGovernorOf(iOperator);
      _requireNonZeroAddress(iGovernor);
      _requireNonZeroAddress(iOperator);

      // Check existing operators
      removeds[i] = $._governorWeight[iGovernor] > 0 && $._operatorWeight[iOperator] > 0;

      // Only remove the valid operator
      if (removeds[i]) {
        uint removingVoteWeight = $._governorWeight[iGovernor];

        // Remove governor from list, update governor weight
        uint lastIdx = $._governors.length - 1;
        $._governors[idx] = $._governors[lastIdx];
        $._governors.pop();
        delete $._governorWeight[iGovernor];

        // Remove operator from list, update operator weight
        $._operators[idx] = $._operators[lastIdx];
        $._operators.pop();
        delete $._operatorWeight[iOperator];

        accumulatedWeight += removingVoteWeight;
      }
    }

    $._totalWeight -= accumulatedWeight;

    _notifyRegisters(IBridgeManagerCallback.onBridgeOperatorsRemoved.selector, abi.encode(removingOperators, removeds));

    emit BridgeOperatorsRemoved(removeds, removingOperators);
  }

  function _findOperatorInArray(address addr) internal view returns (bool found, uint idx) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    for (uint i; i < $._operators.length; i++) {
      if (addr == $._operators[i]) {
        return (true, i);
      }
    }

    return (false, type(uint256).max);
  }

  function _findGovernorInArray(address addr) internal view returns (bool found, uint idx) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    for (uint i; i < $._governors.length; i++) {
      if (addr == $._governors[i]) {
        return (true, i);
      }
    }

    return (false, type(uint256).max);
  }

  // ================= MANAGER VIEW METHODS =============

  /**
   * @inheritdoc IBridgeManager
   */
  function totalBridgeOperator() external view returns (uint256) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._operators.length;
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function isBridgeOperator(address addr) external view returns (bool) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._operatorWeight[addr] > 0;
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getBridgeOperators() external view returns (address[] memory) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._operators;
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernors() external view returns (address[] memory) {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();
    return $._governors;
  }

  /**
   * @inheritdoc IBridgeManager
   * @custom:deprecated Deprecated due to high gas consume in new design.
   */
  function getBridgeOperatorOf(address[] memory /*governors*/) external pure returns (address[] memory /*bridgeOperators*/) {
    revert("Deprecated method");
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getOperatorOf(address governor) external view returns (address operator) {
    (bool found, uint idx) = _findGovernorInArray(governor);
    if (!found) revert ErrGovernorNotFound(governor);

    return _getBridgeManagerStorage()._operators[idx];
  }

  /**
   * @inheritdoc IBridgeManager
   * @custom:deprecated Deprecated due to high gas consume in new design.
   */
  function getGovernorsOf(address[] calldata /*bridgeOperators*/) external pure returns (address[] memory /*governors*/) {
    revert("Deprecated method");
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getGovernorOf(address operator) external view returns (address governor) {
    (governor, ) = _getGovernorOf(operator);
  }

  function _getGovernorOf(address operator) internal view returns (address governor, uint idx) {
    (bool found, uint foundId) = _findOperatorInArray(operator);
    if (!found) revert ErrOperatorNotFound(operator);

    return (_getBridgeManagerStorage()._governors[foundId], foundId);
  }

  /**
   * @inheritdoc IBridgeManager
   */
  function getFullBridgeOperatorInfos()
    external
    view
    returns (address[] memory governors, address[] memory bridgeOperators, uint96[] memory weights)
  {
    BridgeManagerStorage storage $ = _getBridgeManagerStorage();

    governors = $._governors;
    bridgeOperators = $._operators;
    weights = _getGovernorWeights(governors);
  }
}
