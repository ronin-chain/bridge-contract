// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import { TokenOwner } from "src/libraries/LibTokenOwner.sol";
import { TokenInfo, TokenStandard, Transfer } from "src/libraries/Transfer.sol";
import { MappedTokenConsumer } from "src/interfaces/consumers/MappedTokenConsumer.sol";
import { VoteStatusConsumer } from "src/interfaces/consumers/VoteStatusConsumer.sol";
import { ContractType } from "src/utils/ContractType.sol";
import { RoleAccess } from "src/utils/RoleAccess.sol";
import { SignatureConsumer } from "src/interfaces/consumers/SignatureConsumer.sol";

interface IMainchainGatewayV3 {
  error ErrContractTypeNotFound(ContractType contractType);
  error ErrERC1155MintingFailed();
  error ErrERC20MintingFailed();
  error ErrERC721MintingFailed();
  error ErrEmptyArray();
  error ErrInvalidChainId(bytes4 msgSig, uint256 actual, uint256 expected);
  error ErrInvalidInfo();
  error ErrInvalidOrder(bytes4 msgSig);
  error ErrInvalidPercentage();
  error ErrInvalidReceipt();
  error ErrInvalidReceiptKind();
  error ErrInvalidRequest();
  error ErrInvalidSigner(address signer, uint256 weight, SignatureConsumer.Signature sig);
  error ErrInvalidThreshold(bytes4 msgSig);
  error ErrInvalidTokenStandard();
  error ErrLengthMismatch(bytes4 msgSig);
  error ErrNotWhitelistedToken(address token);
  error ErrNullHighTierVoteWeightProvided(bytes4 msgSig);
  error ErrNullMinVoteWeightProvided(bytes4 msgSig);
  error ErrNullTotalWeightProvided(bytes4 msgSig);
  error ErrQueryForApprovedWithdrawal();
  error ErrQueryForInsufficientVoteWeight();
  error ErrQueryForProcessedWithdrawal();
  error ErrReachedDailyWithdrawalLimit();
  error ErrRestricted(bytes4 fnSig, TokenStandard standard);
  error ErrTokenCouldNotTransfer(TokenInfo tokenInfo, address to, address token);
  error ErrTokenCouldNotTransferFrom(TokenInfo tokenInfo, address from, address to, address token);
  error ErrUnauthorized(bytes4 msgSig, RoleAccess expectedRole);
  error ErrUnexpectedInternalCall(bytes4 msgSig, ContractType expectedContractType, address actual);
  error ErrUnsupportedStandard();
  error ErrUnsupportedToken();
  error ErrWhitelistWrappedTokenInstead();
  error ErrZeroCodeContract(address addr);

  event ContractUpdated(ContractType indexed contractType, address indexed addr);
  event DailyWithdrawalLimitsUpdated(address[] tokens, uint256[] limits);
  event DepositRequested(bytes32 receiptHash, Transfer.Receipt receipt);
  event HighTierThresholdsUpdated(address[] tokens, uint256[] thresholds);
  event HighTierVoteWeightThresholdUpdated(
    uint256 indexed nonce, uint256 indexed numerator, uint256 indexed denominator, uint256 previousNumerator, uint256 previousDenominator
  );
  event Initialized(uint8 version);
  event LockedThresholdsUpdated(address[] tokens, uint256[] thresholds);
  event Paused(address account);
  event Restricted(address indexed by, bytes4 indexed fnSig, uint8 enumBitmap);
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event ThresholdUpdated(uint256 indexed nonce, uint256 indexed numerator, uint256 indexed denominator, uint256 previousNumerator, uint256 previousDenominator);
  event TokenMapped(address[] mainchainTokens, address[] roninTokens, TokenStandard[] standards);
  event UnRestricted(address indexed by, bytes4 indexed fnSig);
  event UnlockFeePercentagesUpdated(address[] tokens, uint256[] percentages);
  event Unpaused(address account);
  event WhitelistUpdated(address indexed by, address[] tokens, address[] recipients, uint64[] remoteChainSelectors);
  event WithdrawalLocked(bytes32 receiptHash, Transfer.Receipt receipt);
  event WithdrawalUnlocked(bytes32 receiptHash, Transfer.Receipt receipt);
  event Withdrew(bytes32 receiptHash, Transfer.Receipt receipt);
  event WrappedNativeTokenContractUpdated(address weth);

  receive() external payable;

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
  function DOMAIN_SEPARATOR() external view returns (bytes32);
  function WITHDRAWAL_UNLOCKER_ROLE() external view returns (bytes32);
  function _MAX_PERCENTAGE() external view returns (uint256);
  function checkHighTierVoteWeightThreshold(
    uint256 _voteWeight
  ) external view returns (bool);
  function checkThreshold(
    uint256 _voteWeight
  ) external view returns (bool);
  function dailyWithdrawalLimit(
    address
  ) external view returns (uint256);
  function depositCount() external view returns (uint256);
  function emergencyPauser() external view returns (address);
  function getContract(
    ContractType contractType
  ) external view returns (address contract_);
  function getHighTierVoteWeightThreshold() external view returns (uint256, uint256);
  function getRoleAdmin(
    bytes32 role
  ) external view returns (bytes32);
  function getRoleMember(bytes32 role, uint256 index) external view returns (address);
  function getRoleMemberCount(
    bytes32 role
  ) external view returns (uint256);
  function getRoninToken(
    address mainchainToken
  ) external view returns (MappedTokenConsumer.MappedToken memory token);
  function getThreshold() external view returns (uint256 num_, uint256 denom_);
  function getWhitelistedAddresses(
    address[] memory tokens
  ) external view returns (address[] memory whitelisteds);
  function grantRole(bytes32 role, address account) external;
  function hasRole(bytes32 role, address account) external view returns (bool);
  function highTierThreshold(
    address
  ) external view returns (uint256);
  function initializeV5(address migrator, address newEmergencyPauser) external;
  function lastDateSynced(
    address
  ) external view returns (uint256);
  function lastSyncedWithdrawal(
    address
  ) external view returns (uint256);
  function lockedThreshold(
    address
  ) external view returns (uint256);
  function mapTokens(address[] memory _mainchainTokens, address[] memory _roninTokens, TokenStandard[] memory _standards) external;
  function mapTokensAndThresholds(
    address[] memory _mainchainTokens,
    address[] memory _roninTokens,
    TokenStandard[] memory _standards,
    uint256[][4] memory _thresholds
  ) external;
  function migrateERC20(address[] memory tokens, uint256[] memory amounts) external;
  function migrateERC721(address[] memory tokens, uint256[] memory ids) external;
  function minimumVoteWeight() external view returns (uint256);
  function nonce() external view returns (uint256);
  function onBridgeOperatorsAdded(address[] memory operators, uint96[] memory weights, bool[] memory addeds) external returns (bytes4);
  function onBridgeOperatorsRemoved(address[] memory operators, bool[] memory removeds) external returns (bytes4);
  function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) external returns (bytes4);
  function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
  function pause() external;
  function paused() external view returns (bool);
  function reachedWithdrawalLimit(address _token, uint256 _quantity) external view returns (bool);
  function renounceRole(bytes32 role, address account) external;
  function requestDepositFor(
    Transfer.Request memory _request
  ) external payable;
  function restrict(bytes4 fnSig, uint8 enumBitmap) external;
  function restricted(bytes4 fnSig, TokenStandard standard) external view returns (bool yes);
  function revokeRole(bytes32 role, address account) external;
  function roninChainId() external view returns (uint256);
  function setContract(ContractType contractType, address addr) external;
  function setDailyWithdrawalLimits(address[] memory _tokens, uint256[] memory _limits) external;
  function setEmergencyPauser(
    address _addr
  ) external;
  function setHighTierThresholds(address[] memory _tokens, uint256[] memory _thresholds) external;
  function setHighTierVoteWeightThreshold(uint256 _numerator, uint256 _denominator) external returns (uint256 _previousNum, uint256 _previousDenom);
  function setLockedThresholds(address[] memory _tokens, uint256[] memory _thresholds) external;
  function setThreshold(uint256 num, uint256 denom) external;
  function setUnlockFeePercentages(address[] memory _tokens, uint256[] memory _percentages) external;
  function setWrappedNativeTokenContract(
    address _wrappedToken
  ) external;
  function submitWithdrawal(Transfer.Receipt memory _receipt, SignatureConsumer.Signature[] memory _signatures) external returns (bool _locked);
  function supportsInterface(
    bytes4 interfaceId
  ) external view returns (bool);
  function unlockFeePercentages(
    address
  ) external view returns (uint256);
  function unlockWithdrawal(
    Transfer.Receipt memory receipt
  ) external;
  function unpause() external;
  function whitelist(address[] memory tokens, address[] memory recipients, uint64[] memory remoteChainSelectors) external;
  function withdrawalHash(
    uint256
  ) external view returns (bytes32);
  function withdrawalLocked(
    uint256
  ) external view returns (bool);
  function wrappedNativeToken() external view returns (address);
}
