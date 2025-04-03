// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { TokenOwner } from "src/libraries/LibTokenOwner.sol";
import { TokenInfo, TokenStandard, Transfer } from "src/libraries/Transfer.sol";
import { MappedTokenConsumer } from "src/interfaces/consumers/MappedTokenConsumer.sol";
import { VoteStatusConsumer } from "src/interfaces/consumers/VoteStatusConsumer.sol";
import { ContractType } from "src/utils/ContractType.sol";
import { RoleAccess } from "src/utils/RoleAccess.sol";

interface IRoninGatewayV3 {
  error ErrAlreadyVoted(address voter);
  error ErrContractTypeNotFound(ContractType contractType);
  error ErrERC1155MintingFailed();
  error ErrERC20MintingFailed();
  error ErrERC721MintingFailed();
  error ErrEmptyArray();
  error ErrInvalidChainId(bytes4 msgSig, uint256 actual, uint256 expected);
  error ErrInvalidInfo();
  error ErrInvalidReceipt();
  error ErrInvalidReceiptKind();
  error ErrInvalidRequest();
  error ErrInvalidThreshold(bytes4 msgSig);
  error ErrInvalidTokenStandard();
  error ErrInvalidTrustedThreshold();
  error ErrLengthMismatch(bytes4 msgSig);
  error ErrNotWhitelistedToken(address token);
  error ErrNullMinVoteWeightProvided(bytes4 msgSig);
  error ErrQueryForTooSmallQuantity();
  error ErrRestricted(bytes4 fnSig, TokenStandard standard);
  error ErrTokenCouldNotTransfer(TokenInfo tokenInfo, address to, address token);
  error ErrTokenCouldNotTransferFrom(TokenInfo tokenInfo, address from, address to, address token);
  error ErrUnauthorized(bytes4 msgSig, RoleAccess expectedRole);
  error ErrUnsupportedStandard();
  error ErrUnsupportedToken();
  error ErrWhitelistWrappedTokenInstead();
  error ErrWithdrawalsMigrated();
  error ErrWithdrawnOnMainchainAlready();
  error ErrZeroCodeContract(address addr);

  event ContractUpdated(ContractType indexed contractType, address indexed addr);
  event DepositVoted(address indexed bridgeOperator, uint256 indexed id, uint256 indexed chainId, bytes32 receiptHash);
  event Deposited(bytes32 receiptHash, Transfer.Receipt receipt);
  event Initialized(uint8 version);
  event MainchainWithdrew(bytes32 receiptHash, Transfer.Receipt receipt);
  event MinimumThresholdsUpdated(address[] tokens, uint256[] threshold);
  event Paused(address account);
  event Restricted(address indexed by, bytes4 indexed fnSig, uint8 stdBitmap);
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event ThresholdUpdated(uint256 indexed nonce, uint256 indexed numerator, uint256 indexed denominator, uint256 previousNumerator, uint256 previousDenominator);
  event TokenMapped(address[] roninTokens, address[] mainchainTokens, uint256[] chainIds, TokenStandard[] standards);
  event TokenUnmapped(address[] roninTokens, uint256[] chainIds);
  event TrustedThresholdUpdated(
    uint256 indexed nonce, uint256 indexed numerator, uint256 indexed denominator, uint256 previousNumerator, uint256 previousDenominator
  );
  event UnRestricted(address indexed by, bytes4 indexed fnSig);
  event Unpaused(address account);
  event WhitelistUpdated(address indexed by, address[] tokens, address[] recipients, uint64[] remoteChainSelectors);
  event WithdrawalRequested(bytes32 receiptHash, Transfer.Receipt);
  event WithdrawalSignaturesRequested(bytes32 receiptHash, Transfer.Receipt);

  receive() external payable;

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
  function bulkRequestWithdrawalFor(Transfer.Request[] memory requests, uint256 chainId) external;
  function bulkSubmitWithdrawalSignatures(uint256[] memory withdrawals, bytes[] memory signatures) external;
  function checkThreshold(
    uint256 _voteWeight
  ) external view returns (bool);
  function depositFor(
    Transfer.Receipt memory _receipt
  ) external;
  function depositVote(uint256, uint256) external view returns (VoteStatusConsumer.VoteStatus status, bytes32 finalHash, uint256 expiredAt, uint256 createdAt);
  function depositVoted(uint256 _chainId, uint256 _depositId, address _voter) external view returns (bool);
  function emergencyPauser() external view returns (address);
  function getContract(
    ContractType contractType
  ) external view returns (address contract_);
  function getMainchainToken(address _roninToken, uint256 _chainId) external view returns (MappedTokenConsumer.MappedToken memory _token);
  function getRoleAdmin(
    bytes32 role
  ) external view returns (bytes32);
  function getRoleMember(bytes32 role, uint256 index) external view returns (address);
  function getRoleMemberCount(
    bytes32 role
  ) external view returns (uint256);
  function getThreshold() external view returns (uint256 num_, uint256 denom_);
  function getTrustedThreshold() external view returns (uint256 trustedNum_, uint256 trustedDenom_);
  function getWhitelistedAddresses(
    address[] memory tokens
  ) external view returns (address[] memory whitelisteds);
  function getWithdrawalSignatures(uint256 withdrawalId, address[] memory operators) external view returns (bytes[] memory _signatures);
  function grantRole(bytes32 role, address account) external;
  function hasRole(bytes32 role, address account) external view returns (bool);
  function initializeV4(address migrator, address newEmergencyPauser) external;
  function mainchainWithdrew(
    uint256 _withdrawalId
  ) external view returns (bool);
  function mainchainWithdrewVote(
    uint256
  ) external view returns (VoteStatusConsumer.VoteStatus status, bytes32 finalHash, uint256 expiredAt, uint256 createdAt);
  function mainchainWithdrewVoted(uint256 _withdrawalId, address _voter) external view returns (bool);
  function mapTokens(address[] memory _roninTokens, address[] memory _mainchainTokens, uint256[] memory _chainIds, TokenStandard[] memory _standards) external;
  function mapTokensWithMinThresholds(
    address[] memory roninTokens_,
    address[] memory mainchainTokens_,
    uint256[] memory chainIds_,
    TokenStandard[] memory standards_,
    uint256[] memory minimumThresholds_
  ) external;
  function migrateERC20(address[] memory tokens, uint256[] memory amounts) external;
  function migrateERC721(address[] memory tokens, uint256[] memory ids) external;
  function minimumThreshold(
    address mainchainToken
  ) external view returns (uint256);
  function minimumVoteWeight() external view returns (uint256);
  function nonce() external view returns (uint256);
  function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) external returns (bytes4);
  function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
  function pause() external;
  function paused() external view returns (bool);
  function renounceRole(bytes32 role, address account) external;
  function requestWithdrawalFor(Transfer.Request memory _request, uint256 _chainId) external;
  function requestWithdrawalSignatures(
    uint256 _withdrawalId
  ) external;
  function restrict(bytes4 fnSig, uint8 enumBitmap) external;
  function restricted(bytes4 fnSig, TokenStandard standard) external view returns (bool yes);
  function revokeRole(bytes32 role, address account) external;
  function setContract(ContractType contractType, address addr) external;
  function setEmergencyPauser(
    address _addr
  ) external;
  function setMinimumThresholds(address[] memory mainchainTokens_, uint256[] memory thresholds_) external;
  function setThreshold(uint256 _numerator, uint256 _denominator) external;
  function setTrustedThreshold(uint256 _trustedNumerator, uint256 _trustedDenominator) external returns (uint256, uint256);
  function supportsInterface(
    bytes4 interfaceId
  ) external view returns (bool);
  function tryBulkAcknowledgeMainchainWithdrew(
    uint256[] memory _withdrawalIds
  ) external returns (bool[] memory _executedReceipts);
  function tryBulkDepositFor(
    Transfer.Receipt[] memory receipts
  ) external returns (bool[] memory _executedReceipts);
  function unmapTokens(address[] memory roninTokens_, uint256[] memory chainIds_) external;
  function unpause() external;
  function whitelist(address[] memory tokens, address[] memory recipients, uint64[] memory remoteChainSelectors) external;
  function withdrawal(
    uint256
  ) external view returns (uint256 id, Transfer.Kind kind, TokenOwner memory mainchain, TokenOwner memory ronin, TokenInfo memory info);
  function withdrawalCount() external view returns (uint256);
  function withdrawalStatVote(
    uint256
  ) external view returns (VoteStatusConsumer.VoteStatus status, bytes32 finalHash, uint256 expiredAt, uint256 createdAt);
  function wrappedNativeToken() external view returns (address);
}
