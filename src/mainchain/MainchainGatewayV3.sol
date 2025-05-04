// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IBridgeManager } from "../interfaces/bridge/IBridgeManager.sol";
import { IBridgeManagerCallback } from "../interfaces/bridge/IBridgeManagerCallback.sol";
import { HasContracts, ContractType } from "../extensions/collections/HasContracts.sol";
import { ErrInvalidRequest } from "src/utils/CommonErrors.sol";
import { AssetMigration } from "src/extensions/AssetMigration.sol";
import "../extensions/WethUnwrapper.sol";
import "../extensions/WithdrawalLimitation.sol";
import "../extensions/AssetMigration.sol";
import "../libraries/Transfer.sol";
import { TokenStandard } from "../libraries/LibTokenInfo.sol";
import "../interfaces/IMainchainGatewayV3.sol";

contract MainchainGatewayV3 is
  WithdrawalLimitation,
  Initializable,
  AccessControlEnumerable,
  ERC1155Holder,
  IMainchainGatewayV3,
  HasContracts,
  AssetMigration,
  IBridgeManagerCallback
{
  using LibTokenInfo for TokenInfo;
  using Transfer for Transfer.Request;
  using Transfer for Transfer.Receipt;

  /// @dev Withdrawal unlocker role hash
  bytes32 public constant WITHDRAWAL_UNLOCKER_ROLE = keccak256("WITHDRAWAL_UNLOCKER_ROLE");

  /// @dev Wrapped native token address
  IWETH public override(AssetMigration, IMainchainGatewayV3) wrappedNativeToken;
  /// @dev Ronin network id
  uint256 public roninChainId;
  /// @dev Total deposit
  uint256 public depositCount;
  /// @dev Domain separator
  bytes32 internal _domainSeparator;
  /// @dev Mapping from mainchain token => token address on Ronin network
  mapping(address => MappedToken) internal _roninToken;
  /// @dev Mapping from withdrawal id => withdrawal hash
  mapping(uint256 => bytes32) public withdrawalHash;
  /// @dev Mapping from withdrawal id => locked
  mapping(uint256 => bool) public withdrawalLocked;

  /// @custom:deprecated Previously `_bridgeOperatorAddedBlock` (mapping(address => uint256))
  uint256 private ______deprecatedBridgeOperatorAddedBlock;
  /// @custom:deprecated Previously `_bridgeOperators` (uint256[])
  uint256 private ______deprecatedBridgeOperators;

  uint96 internal _totalOperatorWeight;
  mapping(address operator => uint96 weight) internal _operatorWeight;
  /// @custom:deprecated Previously `_wethUnwrapper` (address)
  uint256 private ______deprecatedWethUnwrapper;

  constructor() {
    _disableInitializers();
  }

  receive() external payable {
    _fallback();
  }

  function initializeV5(
    address migrator,
    address newEmergencyPauser,
    address[] calldata tokens,
    address[] calldata recipients,
    uint64[] calldata remoteChainSelectors
  ) external reinitializer(5) {
    _grantRole(_MIGRATOR_ROLE, migrator);

    uint8 forbidAllIndicator = type(uint8).max;

    _restrict(this.requestDepositFor.selector, forbidAllIndicator);
    _restrict(this.submitWithdrawal.selector, forbidAllIndicator);

    if (tokens.length != 0 || recipients.length != 0 || remoteChainSelectors.length != 0) {
      _whitelist(tokens, recipients, remoteChainSelectors);
    }
    emergencyPauser = newEmergencyPauser;
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
    return _domainSeparator;
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function setWrappedNativeTokenContract(
    IWETH _wrappedToken
  ) external virtual onlyProxyAdmin {
    _setWrappedNativeTokenContract(_wrappedToken);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function requestDepositFor(
    Transfer.Request calldata _request
  ) external payable virtual whenNotPaused {
    _requestDepositFor(_request, msg.sender);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function submitWithdrawal(Transfer.Receipt calldata _receipt, Signature[] calldata _signatures) external virtual whenNotPaused returns (bool _locked) {
    return _submitWithdrawal(_receipt, _signatures);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function unlockWithdrawal(
    Transfer.Receipt calldata receipt
  ) external onlyRole(WITHDRAWAL_UNLOCKER_ROLE) {
    bytes32 _receiptHash = receipt.hash();
    if (withdrawalHash[receipt.id] != receipt.hash()) {
      revert ErrInvalidReceipt();
    }
    if (!withdrawalLocked[receipt.id]) {
      revert ErrQueryForApprovedWithdrawal();
    }
    delete withdrawalLocked[receipt.id];
    emit WithdrawalUnlocked(_receiptHash, receipt);

    address token = receipt.mainchain.tokenAddr;
    if (receipt.info.erc == TokenStandard.ERC20) {
      TokenInfo memory feeInfo = receipt.info;
      feeInfo.quantity = _computeFeePercentage(receipt.info.quantity, unlockFeePercentages[token]);
      TokenInfo memory withdrawInfo = receipt.info;
      withdrawInfo.quantity = receipt.info.quantity - feeInfo.quantity;

      feeInfo.handleAssetOut(payable(msg.sender), token, wrappedNativeToken);
      withdrawInfo.handleAssetOut(payable(receipt.mainchain.addr), token, wrappedNativeToken);
    } else {
      receipt.info.handleAssetOut(payable(receipt.mainchain.addr), token, wrappedNativeToken);
    }

    emit Withdrew(_receiptHash, receipt);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function mapTokens(address[] calldata _mainchainTokens, address[] calldata _roninTokens, TokenStandard[] calldata _standards) external virtual onlyProxyAdmin {
    if (_mainchainTokens.length == 0) revert ErrEmptyArray();
    _mapTokens(_mainchainTokens, _roninTokens, _standards);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function mapTokensAndThresholds(
    address[] calldata _mainchainTokens,
    address[] calldata _roninTokens,
    TokenStandard[] calldata _standards,
    // _thresholds[0]: highTierThreshold
    // _thresholds[1]: lockedThreshold
    // _thresholds[2]: unlockFeePercentages
    // _thresholds[3]: dailyWithdrawalLimit
    uint256[][4] calldata _thresholds
  ) external virtual onlyProxyAdmin {
    if (_mainchainTokens.length == 0) revert ErrEmptyArray();
    _mapTokens(_mainchainTokens, _roninTokens, _standards);
    _setHighTierThresholds(_mainchainTokens, _thresholds[0]);
    _setLockedThresholds(_mainchainTokens, _thresholds[1]);
    _setUnlockFeePercentages(_mainchainTokens, _thresholds[2]);
    _setDailyWithdrawalLimits(_mainchainTokens, _thresholds[3]);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function getRoninToken(
    address mainchainToken
  ) public view returns (MappedToken memory token) {
    token = _roninToken[mainchainToken];
    if (token.tokenAddr == address(0)) revert ErrUnsupportedToken();
  }

  /**
   * @dev Maps mainchain tokens to Ronin network.
   *
   * Requirement:
   * - The arrays have the same length.
   *
   * Emits the `TokenMapped` event.
   *
   */
  function _mapTokens(address[] calldata mainchainTokens, address[] calldata roninTokens, TokenStandard[] calldata standards) internal virtual {
    if (!(mainchainTokens.length == roninTokens.length && mainchainTokens.length == standards.length)) revert ErrLengthMismatch(msg.sig);

    for (uint256 i; i < mainchainTokens.length; ++i) {
      _roninToken[mainchainTokens[i]].tokenAddr = roninTokens[i];
      _roninToken[mainchainTokens[i]].erc = standards[i];
    }

    emit TokenMapped(mainchainTokens, roninTokens, standards);
  }

  /**
   * @dev Submits withdrawal receipt.
   *
   * Requirements:
   * - The receipt kind is withdrawal.
   * - The receipt is to withdraw on this chain.
   * - The receipt is not used to withdraw before.
   * - The withdrawal is not reached the limit threshold.
   * - The signer weight total is larger than or equal to the minimum threshold.
   * - The signature signers are in order.
   *
   * Emits the `Withdrew` once the assets are released.
   *
   */
  function _submitWithdrawal(Transfer.Receipt calldata receipt, Signature[] memory signatures) internal virtual returns (bool locked) {
    uint256 id = receipt.id;
    uint256 quantity = receipt.info.quantity;
    address tokenAddr = receipt.mainchain.tokenAddr;

    receipt.info.validate();
    _requireNotRestricted(receipt.info.erc);
    if (receipt.kind != Transfer.Kind.Withdrawal) revert ErrInvalidReceiptKind();

    if (receipt.mainchain.chainId != block.chainid) {
      revert ErrInvalidChainId(msg.sig, receipt.mainchain.chainId, block.chainid);
    }

    MappedToken memory token = getRoninToken(receipt.mainchain.tokenAddr);

    if (!(token.erc == receipt.info.erc && token.tokenAddr == receipt.ronin.tokenAddr && receipt.ronin.chainId == roninChainId)) {
      revert ErrInvalidReceipt();
    }

    if (withdrawalHash[id] != 0) revert ErrQueryForProcessedWithdrawal();

    if (!(receipt.info.erc == TokenStandard.ERC721 || !_reachedWithdrawalLimit(tokenAddr, quantity))) {
      revert ErrReachedDailyWithdrawalLimit();
    }

    bytes32 receiptHash = receipt.hash();
    bytes32 receiptDigest = Transfer.receiptDigest(_domainSeparator, receiptHash);

    uint256 minimumWeight;
    (minimumWeight, locked) = _computeMinVoteWeight(receipt.info.erc, tokenAddr, quantity);

    {
      bool passed;
      address signer;
      address lastSigner;
      Signature memory sig;
      uint256 accumWeight;
      for (uint256 i; i < signatures.length; i++) {
        sig = signatures[i];
        signer = ECDSA.recover({ hash: receiptDigest, v: sig.v, r: sig.r, s: sig.s });
        if (lastSigner >= signer) revert ErrInvalidOrder(msg.sig);

        lastSigner = signer;

        uint256 w = _getWeight(signer);
        if (w == 0) revert ErrInvalidSigner(signer, w, sig);

        accumWeight += w;
        if (accumWeight >= minimumWeight) {
          passed = true;
          break;
        }
      }

      if (!passed) revert ErrQueryForInsufficientVoteWeight();
      withdrawalHash[id] = receiptHash;
    }

    if (locked) {
      withdrawalLocked[id] = true;
      emit WithdrawalLocked(receiptHash, receipt);
      return locked;
    }

    _recordWithdrawal(tokenAddr, quantity);
    receipt.info.handleAssetOut(payable(receipt.mainchain.addr), tokenAddr, wrappedNativeToken);
    emit Withdrew(receiptHash, receipt);
  }

  /**
   * @dev Requests deposit made by `_requester` address.
   *
   * Requirements:
   * - The token info is valid.
   * - The `msg.value` is 0 while depositing ERC20 token.
   * - The `msg.value` is equal to deposit quantity while depositing native token.
   *
   * Emits the `DepositRequested` event.
   *
   */
  function _requestDepositFor(Transfer.Request memory _request, address _requester) internal virtual {
    MappedToken memory _token;
    address mainchainWeth = address(wrappedNativeToken);

    _request.info.validate();
    _requireNotRestricted(_request.info.erc);
    if (_request.tokenAddr == address(0)) {
      if (_request.info.quantity != msg.value) revert ErrInvalidRequest();

      _token = getRoninToken(mainchainWeth);
      if (_token.erc != _request.info.erc) revert ErrInvalidTokenStandard();

      _request.tokenAddr = mainchainWeth;
    } else {
      if (msg.value != 0) revert ErrInvalidRequest();

      _token = getRoninToken(_request.tokenAddr);
      if (_token.erc != _request.info.erc) revert ErrInvalidTokenStandard();

      _request.info.handleAssetIn(_requester, _request.tokenAddr);

      /**
       * Withdraw if token is WETH
       *
       * `IWETH.withdraw` only sends 2300 gas, which might be insufficient when recipient is a proxy, in this case, gateway proxy.
       * However, the storage accesses of proxy relating variables on Shanghai hardfork are warm-access, only requires additional 100*2 gas. So it should be safe,
       * no need to go via a mediator of WETH unwrapper.
       */
      if (mainchainWeth == _request.tokenAddr) {
        IWETH(mainchainWeth).withdraw(_request.info.quantity);
      }
    }

    uint256 _depositId = depositCount++;
    Transfer.Receipt memory _receipt = _request.into_deposit_receipt(_requester, _depositId, _token.tokenAddr, roninChainId);

    emit DepositRequested(_receipt.hash(), _receipt);
  }

  /**
   * @dev Returns the minimum vote weight for the token.
   */
  function _computeMinVoteWeight(TokenStandard _erc, address _token, uint256 _quantity) internal virtual returns (uint256 _weight, bool _locked) {
    uint256 _totalWeight = _getTotalWeight();
    _weight = _minimumVoteWeight(_totalWeight);
    if (_erc == TokenStandard.ERC20) {
      if (highTierThreshold[_token] <= _quantity) {
        _weight = _highTierVoteWeight(_totalWeight);
      }
      _locked = _lockedWithdrawalRequest(_token, _quantity);
    }
  }

  /**
   * @dev Update domain separator.
   */
  function _updateDomainSeparator() internal {
    /*
     * _domainSeparator = keccak256(
     *   abi.encode(
     *     keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
     *     keccak256("MainchainGatewayV2"),
     *     keccak256("2"),
     *     block.chainid,
     *     address(this)
     *   )
     * );
     */
    assembly {
      let ptr := mload(0x40)
      // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
      mstore(ptr, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
      // keccak256("MainchainGatewayV2")
      mstore(add(ptr, 0x20), 0x159f52c1e3a2b6a6aad3950adf713516211484e0516dad685ea662a094b7c43b)
      // keccak256("2")
      mstore(add(ptr, 0x40), 0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68eb14a5)
      mstore(add(ptr, 0x60), chainid())
      mstore(add(ptr, 0x80), address())
      sstore(_domainSeparator.slot, keccak256(ptr, 0xa0))
    }
  }

  /**
   * @dev Sets the WETH contract.
   *
   * Emits the `WrappedNativeTokenContractUpdated` event.
   *
   */
  function _setWrappedNativeTokenContract(
    IWETH _wrappedToken
  ) internal {
    wrappedNativeToken = _wrappedToken;
    emit WrappedNativeTokenContractUpdated(_wrappedToken);
  }

  /**
   * @dev Receives ETH from WETH or revert if sender is not WETH.
   */
  function _fallback() internal virtual {
    if (msg.sender != address(wrappedNativeToken)) revert ErrInvalidRequest();
  }

  /**
   * @inheritdoc GatewayV3
   */
  function _getTotalWeight() internal view override returns (uint256 totalWeight) {
    totalWeight = _totalOperatorWeight;
    if (totalWeight == 0) revert ErrNullTotalWeightProvided(msg.sig);
  }

  /**
   * @dev Returns the weight of an address.
   */
  function _getWeight(
    address addr
  ) internal view returns (uint256) {
    return _operatorWeight[addr];
  }

  ///////////////////////////////////////////////
  //                CALLBACKS
  ///////////////////////////////////////////////

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsAdded(
    address[] calldata operators,
    uint96[] calldata weights,
    bool[] memory addeds
  ) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint256 length = operators.length;
    if (length != addeds.length || length != weights.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) {
      return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
    }

    for (uint256 i; i < length; ++i) {
      unchecked {
        if (addeds[i]) {
          _totalOperatorWeight += weights[i];
          _operatorWeight[operators[i]] = weights[i];
        }
      }
    }

    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsRemoved(address[] calldata operators, bool[] calldata removeds) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint length = operators.length;
    if (length != removeds.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) {
      return IBridgeManagerCallback.onBridgeOperatorsRemoved.selector;
    }

    uint96 totalRemovingWeight;
    for (uint i; i < length; ++i) {
      unchecked {
        if (removeds[i]) {
          totalRemovingWeight += _operatorWeight[operators[i]];
          delete _operatorWeight[operators[i]];
        }
      }
    }

    _totalOperatorWeight -= totalRemovingWeight;

    return IBridgeManagerCallback.onBridgeOperatorsRemoved.selector;
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerable, IERC165, ERC1155Receiver) returns (bool) {
    return
      interfaceId == type(IMainchainGatewayV3).interfaceId || interfaceId == type(IBridgeManagerCallback).interfaceId || super.supportsInterface(interfaceId);
  }
}
