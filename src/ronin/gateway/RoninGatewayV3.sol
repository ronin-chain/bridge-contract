// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../../extensions/GatewayV3.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/MinimumWithdrawal.sol";
import "../../interfaces/IERC20Mintable.sol";
import "../../interfaces/IERC721Mintable.sol";
import "../../interfaces/bridge/IBridgeTracking.sol";
import "../../interfaces/IRoninGatewayV3.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../libraries/IsolatedGovernance.sol";
import "../../interfaces/bridge/IBridgeManager.sol";

contract RoninGatewayV3 is
  GatewayV3,
  Initializable,
  MinimumWithdrawal,
  AccessControlEnumerable,
  ERC1155Holder,
  VoteStatusConsumer,
  IRoninGatewayV3,
  HasContracts
{
  using LibTokenInfo for TokenInfo;
  using Transfer for Transfer.Request;
  using Transfer for Transfer.Receipt;
  using IsolatedGovernance for IsolatedGovernance.Vote;

  /// @custom:deprecated Previously `withdrawalMigrated` (non-zero value)
  bool private ___deprecated4;
  /// @dev Total withdrawal
  uint256 public withdrawalCount;
  /// @dev Mapping from chain id => deposit id => deposit vote
  mapping(uint256 => mapping(uint256 => IsolatedGovernance.Vote)) public depositVote;
  /// @dev Mapping from withdrawal id => mainchain withdrew vote
  mapping(uint256 => IsolatedGovernance.Vote) public mainchainWithdrewVote;
  /// @dev Mapping from withdrawal id => withdrawal receipt
  mapping(uint256 => Transfer.Receipt) public withdrawal;
  /// @dev Mapping from withdrawal id => validator address => signatures
  mapping(uint256 => mapping(address => bytes)) internal _withdrawalSig;
  /// @dev Mapping from token address => chain id => mainchain token address
  mapping(address => mapping(uint256 => MappedToken)) internal _mainchainToken;

  /// @custom:deprecated Previously `_validatorContract` (non-zero value)
  address private ____deprecated0;
  /// @custom:deprecated Previously `_bridgeTrackingContract` (non-zero value)
  address private ____deprecated1;

  /// @dev Mapping from withdrawal id => vote for recording withdrawal stats
  mapping(uint256 => IsolatedGovernance.Vote) public withdrawalStatVote;

  /// @custom:deprecated Previously `_trustedOrgContract` (non-zero value)
  address private ____deprecated2;

  uint256 internal _trustedNum;
  uint256 internal _trustedDenom;

  constructor () {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  modifier onlyBridgeOperator() {
    _requireBridgeOperator();
    _;
  }

  /**
   * @dev Reverts if the method caller is not bridge operator.
   */
  function _requireBridgeOperator() internal view {
    if (!IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).isBridgeOperator(msg.sender)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.__DEPRECATED_BRIDGE_OPERATOR);
    }
  }

  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    uint256 _numerator,
    uint256 _denominator,
    uint256 _trustedNumerator,
    uint256 _trustedDenominator,
    address[] calldata, /* _withdrawalMigrators */
    // _packedAddresses[0]: roninTokens
    // _packedAddresses[1]: mainchainTokens
    address[][2] calldata _packedAddresses,
    // _packedNumbers[0]: chainIds
    // _packedNumbers[1]: minimumThresholds
    uint256[][2] calldata _packedNumbers,
    TokenStandard[] calldata _standards
  ) external virtual initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    _setThreshold(_numerator, _denominator);
    _setTrustedThreshold(_trustedNumerator, _trustedDenominator);
    if (_packedAddresses[0].length > 0) {
      _mapTokens(_packedAddresses[0], _packedAddresses[1], _packedNumbers[0], _standards);
      _setMinimumThresholds(_packedAddresses[0], _packedNumbers[1]);
    }
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ____deprecated0);
    _setContract(ContractType.BRIDGE_TRACKING, ____deprecated1);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, ____deprecated2);
    delete ____deprecated0;
    delete ____deprecated1;
    delete ____deprecated2;
  }

  function initializeV3(address bridgeAdmin) external reinitializer(3) {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeAdmin);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function getWithdrawalSignatures(
    uint256 withdrawalId,
    address[] calldata operators
  ) external view returns (bytes[] memory _signatures) {
    _signatures = new bytes[](operators.length);
    for (uint256 _i = 0; _i < operators.length;) {
      _signatures[_i] = _withdrawalSig[withdrawalId][operators[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function depositFor(Transfer.Receipt calldata _receipt) external whenNotPaused onlyBridgeOperator {
    _depositFor(_receipt, msg.sender, minimumVoteWeight());
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function tryBulkAcknowledgeMainchainWithdrew(uint256[] calldata _withdrawalIds)
    external
    onlyBridgeOperator
    returns (bool[] memory _executedReceipts)
  {
    address governor = msg.sender;
    uint256 minVoteWeight = minimumVoteWeight();

    uint256 withdrawalId;
    uint length = _withdrawalIds.length;

    _executedReceipts = new bool[](length);
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));

    for (uint256 i; i < length; ++i) {
      withdrawalId = _withdrawalIds[i];
      bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.MainchainWithdrawal, withdrawalId, governor);

      // Mark the withdrawal is executed
      if (mainchainWithdrew(withdrawalId)) {
        _executedReceipts[i] = true;
      }

      // Process all votes, not early-exit to track all votes in BridgeTracking
      IsolatedGovernance.Vote storage _vote = mainchainWithdrewVote[withdrawalId];
      Transfer.Receipt memory _withdrawal = withdrawal[withdrawalId];
      bytes32 _hash = _withdrawal.hash();
      VoteStatus _status = _castIsolatedVote(_vote, governor, minVoteWeight, _hash);
      if (_status == VoteStatus.Approved) {
        _vote.status = VoteStatus.Executed;
        bridgeTrackingContract.handleVoteApproved(IBridgeTracking.VoteKind.MainchainWithdrawal, withdrawalId);
        emit MainchainWithdrew(_hash, _withdrawal);
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function tryBulkDepositFor(Transfer.Receipt[] calldata receipts)
    external
    whenNotPaused
    onlyBridgeOperator
    returns (bool[] memory _executedReceipts)
  {
    uint length = receipts.length;
    _executedReceipts = new bool[](length);
    uint256 minVoteWeight = minimumVoteWeight();

    Transfer.Receipt memory iReceipt;
    for (uint i; i < length; ++i) {
      iReceipt = receipts[i];
      if (depositVote[iReceipt.mainchain.chainId][iReceipt.id].status == VoteStatus.Executed) {
        _executedReceipts[i] = true;
      }

      // Process all votes, not early-exit to track all votes in BridgeTracking
      _depositFor(iReceipt, msg.sender, minVoteWeight);
    }
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function requestWithdrawalFor(Transfer.Request calldata _request, uint256 _chainId) external whenNotPaused {
    _requestWithdrawalFor(_request, msg.sender, _chainId);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function bulkRequestWithdrawalFor(Transfer.Request[] calldata requests, uint256 chainId) external whenNotPaused {
    uint length = requests.length;
    if (length == 0) revert ErrEmptyArray();

    for (uint i; i < length; ++i) {
      _requestWithdrawalFor(requests[i], msg.sender, chainId);
    }
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function requestWithdrawalSignatures(uint256 _withdrawalId) external whenNotPaused {
    if (mainchainWithdrew(_withdrawalId)) revert ErrWithdrawnOnMainchainAlready();

    Transfer.Receipt memory _receipt = withdrawal[_withdrawalId];
    if (_receipt.ronin.chainId != block.chainid) {
      revert ErrInvalidChainId(msg.sig, _receipt.ronin.chainId, block.chainid);
    }

    emit WithdrawalSignaturesRequested(_receipt.hash(), _receipt);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function bulkSubmitWithdrawalSignatures(
    uint256[] calldata withdrawals,
    bytes[] calldata signatures
  ) external whenNotPaused onlyBridgeOperator {
    address operator = msg.sender;

    uint length = withdrawals.length;
    if (!(length > 0 && length == signatures.length)) {
      revert ErrLengthMismatch(msg.sig);
    }

    uint256 _minVoteWeight = minimumVoteWeight();

    uint256 id;
    IBridgeTracking _bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint i; i < length; ++i) {
      id = withdrawals[i];
      _withdrawalSig[id][operator] = signatures[i];
      _bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Withdrawal, id, operator);

      IsolatedGovernance.Vote storage _proposal = withdrawalStatVote[id];
      VoteStatus _status = _castIsolatedVote(_proposal, operator, _minVoteWeight, bytes32(id));
      if (_status == VoteStatus.Approved) {
        _proposal.status = VoteStatus.Executed;
        _bridgeTrackingContract.handleVoteApproved(IBridgeTracking.VoteKind.Withdrawal, id);
      }
    }
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata _chainIds,
    TokenStandard[] calldata _standards
  ) external onlyAdmin {
    if (_roninTokens.length == 0) revert ErrLengthMismatch(msg.sig);
    _mapTokens(_roninTokens, _mainchainTokens, _chainIds, _standards);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function depositVoted(uint256 _chainId, uint256 _depositId, address _voter) external view returns (bool) {
    return depositVote[_chainId][_depositId].voted(_voter);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function mainchainWithdrewVoted(uint256 _withdrawalId, address _voter) external view returns (bool) {
    return mainchainWithdrewVote[_withdrawalId].voted(_voter);
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function mainchainWithdrew(uint256 _withdrawalId) public view returns (bool) {
    return mainchainWithdrewVote[_withdrawalId].status == VoteStatus.Executed;
  }

  /**
   * @inheritdoc IRoninGatewayV3
   */
  function getMainchainToken(address _roninToken, uint256 _chainId) public view returns (MappedToken memory _token) {
    _token = _mainchainToken[_roninToken][_chainId];
    if (_token.tokenAddr == address(0)) revert ErrUnsupportedToken();
  }

  /**
   * @dev Maps Ronin tokens to mainchain networks.
   *
   * Requirement:
   * - The arrays have the same length.
   *
   * Emits the `TokenMapped` event.
   *
   */
  function _mapTokens(
    address[] calldata _roninTokens,
    address[] calldata _mainchainTokens,
    uint256[] calldata _chainIds,
    TokenStandard[] calldata _standards
  ) internal {
    if (!(_roninTokens.length == _mainchainTokens.length && _roninTokens.length == _chainIds.length)) {
      revert ErrLengthMismatch(msg.sig);
    }

    for (uint256 _i; _i < _roninTokens.length;) {
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].tokenAddr = _mainchainTokens[_i];
      _mainchainToken[_roninTokens[_i]][_chainIds[_i]].erc = _standards[_i];

      unchecked {
        ++_i;
      }
    }

    emit TokenMapped(_roninTokens, _mainchainTokens, _chainIds, _standards);
  }

  /**
   * @dev Deposits based on the receipt.
   *
   * Emits the `Deposited` once the assets are released.
   *
   */
  function _depositFor(Transfer.Receipt memory receipt, address operator, uint256 minVoteWeight) internal {
    uint256 id = receipt.id;
    receipt.info.validate();
    if (receipt.kind != Transfer.Kind.Deposit) revert ErrInvalidReceiptKind();
    if (receipt.ronin.chainId != block.chainid) revert ErrInvalidChainId(msg.sig, receipt.ronin.chainId, block.chainid);

    MappedToken memory token = getMainchainToken(receipt.ronin.tokenAddr, receipt.mainchain.chainId);

    if (!(token.erc == receipt.info.erc && token.tokenAddr == receipt.mainchain.tokenAddr)) {
      revert ErrInvalidReceipt();
    }

    IsolatedGovernance.Vote storage _proposal = depositVote[receipt.mainchain.chainId][id];
    bytes32 _receiptHash = receipt.hash();
    VoteStatus status = _castIsolatedVote(_proposal, operator, minVoteWeight, _receiptHash);
    emit DepositVoted(operator, id, receipt.mainchain.chainId, _receiptHash);

    // Transfer assets and handle when the vote is approved.
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    if (status == VoteStatus.Approved) {
      _proposal.status = VoteStatus.Executed;
      receipt.info.handleAssetOut(payable(receipt.ronin.addr), receipt.ronin.tokenAddr, IWETH(address(0)));
      bridgeTrackingContract.handleVoteApproved(IBridgeTracking.VoteKind.Deposit, receipt.id);
      emit Deposited(_receiptHash, receipt);
    }

    // Announce to BridgeTracking to record the vote, after marking the VoteStatus as Executed.
    bridgeTrackingContract.recordVote(IBridgeTracking.VoteKind.Deposit, receipt.id, operator);
  }

  /**
   * @dev Locks the assets and request withdrawal.
   *
   * Requirements:
   * - The token info is valid.
   *
   * Emits the `WithdrawalRequested` event.
   *
   */
  function _requestWithdrawalFor(Transfer.Request calldata _request, address _requester, uint256 _chainId) internal {
    _request.info.validate();
    _checkWithdrawal(_request);
    MappedToken memory _token = getMainchainToken(_request.tokenAddr, _chainId);
    if (_request.info.erc != _token.erc) revert ErrInvalidTokenStandard();

    _request.info.handleAssetIn(_requester, _request.tokenAddr);
    _storeAsReceipt(_request, _chainId, _requester, _token.tokenAddr);
  }

  /**
   * @dev Stores the withdrawal request as a receipt.
   *
   * Emits the `WithdrawalRequested` event.
   *
   */
  function _storeAsReceipt(
    Transfer.Request calldata _request,
    uint256 _chainId,
    address _requester,
    address _mainchainTokenAddr
  ) internal returns (uint256 _withdrawalId) {
    _withdrawalId = withdrawalCount++;
    Transfer.Receipt memory _receipt =
      _request.into_withdrawal_receipt(_requester, _withdrawalId, _mainchainTokenAddr, _chainId);
    withdrawal[_withdrawalId] = _receipt;
    emit WithdrawalRequested(_receipt.hash(), _receipt);
  }

  /**
   * @dev Don't send me RON.
   */
  function _fallback() internal virtual {
    revert ErrInvalidRequest();
  }

  /**
   * @inheritdoc GatewayV3
   */
  function _getTotalWeight() internal view virtual override returns (uint256) {
    return IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getTotalWeight();
  }

  /**
   * @dev Casts and updates the vote result.
   *
   * Requirements:
   * - The vote is not finalized.
   * - The voter has not voted for the round.
   *
   */
  function _castIsolatedVote(
    IsolatedGovernance.Vote storage _v,
    address _voter,
    uint256 _minVoteWeight,
    bytes32 _hash
  ) internal virtual returns (VoteStatus _status) {
    _v.castVote(_voter, _hash);
    uint256 _totalWeight = _getVoteWeight(_v, _hash);
    return _v.syncVoteStatus(_minVoteWeight, _totalWeight, _hash);
  }

  /**
   * @dev Returns the vote weight for a specified hash.
   */
  function _getVoteWeight(
    IsolatedGovernance.Vote storage _v,
    bytes32 _hash
  ) internal view returns (uint256 _totalWeight) {
    (, address[] memory bridgeOperators, uint96[] memory weights) =
      IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getFullBridgeOperatorInfos();
    uint256 length = bridgeOperators.length;
    unchecked {
      for (uint _i; _i < length; ++_i) {
        if (_v.voteHashOf[bridgeOperators[_i]] == _hash) {
          _totalWeight += weights[_i];
        }
      }
    }
  }

  function setTrustedThreshold(
    uint256 _trustedNumerator,
    uint256 _trustedDenominator
  ) external virtual onlyAdmin returns (uint256, uint256) {
    return _setTrustedThreshold(_trustedNumerator, _trustedDenominator);
  }

  /**
   * @dev Returns the threshold about trusted org.
   */
  function getTrustedThreshold() external view virtual returns (uint256 trustedNum_, uint256 trustedDenom_) {
    return (_trustedNum, _trustedDenom);
  }

  /**
   * @dev Sets trusted threshold and returns the old one.
   *
   * Emits the `TrustedThresholdUpdated` event.
   *
   */
  function _setTrustedThreshold(
    uint256 _trustedNumerator,
    uint256 _trustedDenominator
  ) internal virtual returns (uint256 _previousTrustedNum, uint256 _previousTrustedDenom) {
    if (_trustedNumerator > _trustedDenominator) revert ErrInvalidTrustedThreshold();

    _previousTrustedNum = _num;
    _previousTrustedDenom = _denom;
    _trustedNum = _trustedNumerator;
    _trustedDenom = _trustedDenominator;
    unchecked {
      emit TrustedThresholdUpdated(
        nonce++, _trustedNumerator, _trustedDenominator, _previousTrustedNum, _previousTrustedDenom
      );
    }
  }

  /**
   * @dev Returns minimum trusted vote weight.
   */
  function _minimumTrustedVoteWeight(uint256 _totalTrustedWeight) internal view virtual returns (uint256) {
    return (_trustedNum * _totalTrustedWeight + _trustedDenom - 1) / _trustedDenom;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlEnumerable, ERC1155Receiver) returns (bool)
  {
    return AccessControlEnumerable.supportsInterface(interfaceId) || ERC1155Receiver.supportsInterface(interfaceId);
  }
}
