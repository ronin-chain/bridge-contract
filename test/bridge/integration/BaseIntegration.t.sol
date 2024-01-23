// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Base_Test } from "../../Base.t.sol";
import { LibSharedAddress } from "foundry-deployment-kit/libraries/LibSharedAddress.sol";
import { ISharedArgument } from "@ronin/script/interfaces/ISharedArgument.sol";
import { IGeneralConfig } from "foundry-deployment-kit/interfaces/IGeneralConfig.sol";
import { GeneralConfig } from "@ronin/script/GeneralConfig.sol";
import { Network } from "@ronin/script/utils/Network.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { MockWrappedToken } from "@ronin/contracts/mocks/token/MockWrappedToken.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { IWETH } from "@ronin/contracts/interfaces/IWETH.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { GlobalCoreGovernance } from "@ronin/contracts/extensions/sequential-governance/GlobalCoreGovernance.sol";
import { IHasContracts } from "@ronin/contracts/interfaces/collections/IHasContracts.sol";
import { IBridgeManagerCallbackRegister } from "@ronin/contracts/interfaces/bridge/IBridgeManagerCallbackRegister.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";

import { RoninBridgeManagerDeploy } from "@ronin/script/contracts/RoninBridgeManagerDeploy.s.sol";
import { RoninGatewayV3Deploy } from "@ronin/script/contracts/RoninGatewayV3Deploy.s.sol";
import { BridgeTrackingDeploy } from "@ronin/script/contracts/BridgeTrackingDeploy.s.sol";
import { BridgeSlashDeploy } from "@ronin/script/contracts/BridgeSlashDeploy.s.sol";
import { BridgeRewardDeploy } from "@ronin/script/contracts/BridgeRewardDeploy.s.sol";
import { MainchainGatewayV3Deploy } from "@ronin/script/contracts/MainchainGatewayV3Deploy.s.sol";
import { MainchainBridgeManagerDeploy } from "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import { WETHDeploy } from "@ronin/script/contracts/token/WETHDeploy.s.sol";
import { WRONDeploy } from "@ronin/script/contracts/token/WRONDeploy.s.sol";
import { AXSDeploy } from "@ronin/script/contracts/token/AXSDeploy.s.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";

import { ProposalUtils } from "test/helpers/ProposalUtils.t.sol";
import { MockValidatorSet_ForFoundryTest } from "test/mocks/MockValidatorSet_ForFoundryTest.sol";

contract BaseIntegration_Test is Base_Test {
  using Transfer for Transfer.Receipt;

  IGeneralConfig _config;
  ISharedArgument.SharedParameter _param;

  RoninBridgeManager _roninBridgeManager;
  RoninGatewayV3 _roninGatewayV3;
  BridgeTracking _bridgeTracking;
  BridgeSlash _bridgeSlash;
  BridgeReward _bridgeReward;
  MainchainGatewayV3 _mainchainGatewayV3;
  MainchainBridgeManager _mainchainBridgeManager;

  MockWrappedToken _roninWeth;
  MockWrappedToken _roninWron;
  MockERC20 _roninAxs;
  MockERC20 _roninSlp;
  MockERC20 _roninUsdc;

  MockWrappedToken _mainchainWeth;
  MockWrappedToken _mainchainWron;
  MockERC20 _mainchainAxs;
  MockERC20 _mainchainSlp;
  MockERC20 _mainchainUsdc;

  MockValidatorSet_ForFoundryTest _validatorSet;

  ProposalUtils _roninProposalUtils;
  ProposalUtils _mainchainProposalUtils;

  uint256 _roninNonce = 1;
  uint256 _mainchainNonce = 1;

  function setUp() public virtual {
    _deployGeneralConfig();

    _deployContractsOnRonin();
    _deployContractsOnMainchain();

    _initializeRonin();
    _initializeMainchain();
  }

  function _deployContractsOnRonin() internal {
    _config.createFork(Network.RoninLocal.key());
    _config.switchTo(Network.RoninLocal.key());

    _roninGatewayV3 = new RoninGatewayV3Deploy().run();
    _bridgeTracking = new BridgeTrackingDeploy().run();
    _bridgeSlash = new BridgeSlashDeploy().run();
    _bridgeReward = new BridgeRewardDeploy().run();
    _roninBridgeManager = new RoninBridgeManagerDeploy().run();

    _roninWeth = new WETHDeploy().run();
    _roninWron = new WRONDeploy().run();
    _roninAxs = new AXSDeploy().run();
    _roninSlp = new SLPDeploy().run();
    _roninUsdc = new USDCDeploy().run();

    _validatorSet = new MockValidatorSet_ForFoundryTest();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _roninProposalUtils = new ProposalUtils(_param.test.roninChainId);
  }

  function _deployContractsOnMainchain() internal {
    _config.createFork(Network.EthLocal.key());
    _config.switchTo(Network.EthLocal.key());

    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    _mainchainWeth = new WETHDeploy().run();
    _mainchainWron = new WRONDeploy().run();
    _mainchainAxs = new AXSDeploy().run();
    _mainchainSlp = new SLPDeploy().run();
    _mainchainUsdc = new USDCDeploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _mainchainProposalUtils = new ProposalUtils(_param.test.roninChainId);
  }

  function _initializeRonin() internal {
    _config.switchTo(Network.RoninLocal.key());

    _bridgeRewardInitialize();
    _bridgeTrackingInitialize();
    _bridgeSlashInitialize();
    _roninGatewayV3Initialize();
    _constructForRoninBridgeManager();
  }

  function _initializeMainchain() internal {
    _config.switchTo(Network.EthLocal.key());

    _constructForMainchainBridgeManager();
    _mainchainGatewayV3Initialize();
  }

  function _getMainchainAndRoninTokens() internal view returns (address[] memory mainchainTokens, address[] memory roninTokens) {
    uint256 tokenNum = 4;
    mainchainTokens = new address[](tokenNum);
    roninTokens = new address[](tokenNum);

    mainchainTokens[0] = address(_mainchainWeth);
    mainchainTokens[1] = address(_mainchainAxs);
    mainchainTokens[2] = address(_mainchainSlp);
    mainchainTokens[3] = address(_mainchainUsdc);

    roninTokens[0] = address(_roninWeth);
    roninTokens[1] = address(_roninAxs);
    roninTokens[2] = address(_roninSlp);
    roninTokens[3] = address(_roninUsdc);
  }

  function _bridgeRewardInitialize() internal {
    // Bridge rewards
    _param.bridgeReward.validatorSetContract = address(_validatorSet);
    _param.bridgeReward.bridgeManagerContract = address(_roninBridgeManager);
    _param.bridgeReward.bridgeTrackingContract = address(_bridgeTracking);
    _param.bridgeReward.bridgeSlashContract = address(_bridgeSlash);

    ISharedArgument.BridgeRewardParam memory param = _param.bridgeReward;

    _bridgeReward.initialize(
      param.bridgeManagerContract,
      param.bridgeTrackingContract,
      param.bridgeSlashContract,
      param.validatorSetContract,
      param.dposGA,
      param.rewardPerPeriod
    );

    _validatorSet.setCurrentPeriod(10);
    vm.prank(_param.test.dposGA);
    _bridgeReward.initializeREP2();
  }

  function _bridgeTrackingInitialize() internal {
    // Bridge Tracking
    _param.bridgeTracking.validatorContract = address(_validatorSet);
    _param.bridgeTracking.bridgeContract = address(_roninGatewayV3);

    ISharedArgument.BridgeTrackingParam memory param = _param.bridgeTracking;

    _bridgeTracking.initialize(param.bridgeContract, param.validatorContract, param.startedAtBlock);
    _bridgeTracking.initializeV2();
    _bridgeTracking.initializeV3(address(_roninBridgeManager), address(_bridgeSlash), address(_bridgeReward), _param.test.dposGA);
  }

  function _bridgeSlashInitialize() internal {
    // Bridge Slash
    _param.bridgeSlash.validatorContract = address(_validatorSet);
    _param.bridgeSlash.bridgeManagerContract = address(_roninBridgeManager);
    _param.bridgeSlash.bridgeTrackingContract = address(_bridgeTracking);

    ISharedArgument.BridgeSlashParam memory param = _param.bridgeSlash;

    _bridgeSlash.initialize(param.validatorContract, param.bridgeManagerContract, param.bridgeTrackingContract, param.dposGA);

    vm.prank(_param.test.dposGA);
    _bridgeSlash.initializeREP2();
  }

  function _roninGatewayV3Initialize() internal {
    (address[] memory mainchainTokens, address[] memory roninTokens) = _getMainchainAndRoninTokens();
    uint256 tokenNum = mainchainTokens.length;
    uint256[] memory minimumThreshold = new uint256[](tokenNum);
    uint256[] memory chainIds = new uint256[](tokenNum);
    Token.Standard[] memory standards = new Token.Standard[](tokenNum);
    for (uint256 i; i < tokenNum; i++) {
      minimumThreshold[i] = 0;
      chainIds[i] = _param.test.mainchainChainId;
      standards[i] = Token.Standard.ERC20;
    }

    // Ronin Gateway V3
    _param.roninGatewayV3.packedAddresses[0] = roninTokens;
    _param.roninGatewayV3.packedAddresses[1] = mainchainTokens;
    _param.roninGatewayV3.packedNumbers[0] = chainIds;
    _param.roninGatewayV3.packedNumbers[1] = minimumThreshold;
    _param.roninGatewayV3.standards = standards;

    ISharedArgument.RoninGatewayV3Param memory param = _param.roninGatewayV3;

    _roninGatewayV3.initialize(
      param.roleSetter,
      param.numerator,
      param.denominator,
      param.trustedNumerator,
      param.trustedDenominator,
      param.withdrawalMigrators,
      param.packedAddresses,
      param.packedNumbers,
      param.standards
    );

    _roninGatewayV3.initializeV2();
    _roninGatewayV3.initializeV3(address(_roninBridgeManager));
  }

  function _constructForRoninBridgeManager() internal {
    GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](4);
    address[] memory targets = new address[](4);

    options[0] = GlobalProposal.TargetOption.GatewayContract;
    targets[0] = address(_roninGatewayV3);

    options[1] = GlobalProposal.TargetOption.BridgeReward;
    targets[1] = address(_bridgeReward);

    options[2] = GlobalProposal.TargetOption.BridgeSlash;
    targets[2] = address(_bridgeSlash);

    options[3] = GlobalProposal.TargetOption.BridgeTracking;
    targets[3] = address(_bridgeTracking);

    // Ronin Bridge Manager
    _param.roninBridgeManager.bridgeContract = address(_roninGatewayV3);
    _param.roninBridgeManager.callbackRegisters = wrapAddress(address(_bridgeSlash));
    _param.roninBridgeManager.targetOptions = options;
    _param.roninBridgeManager.targets = targets;

    ISharedArgument.BridgeManagerParam memory param = _param.roninBridgeManager;
    uint256 length = param.governors.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    {
      // set targets
      GlobalProposal.GlobalProposalDetail memory globalProposal = _roninProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: abi.encodeCall(GlobalCoreGovernance.updateManyTargetOption, (param.targetOptions, param.targets)),
        gasAmount: 500_000,
        nonce: _roninNonce++
      });

      SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(globalProposal, supports_, signatures);
    }
    {
      // set bridge contract
      GlobalProposal.GlobalProposalDetail memory globalProposal = _roninProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE, param.bridgeContract)),
        gasAmount: 500_000,
        nonce: _roninNonce++
      });

      SignatureConsumer.Signature[] memory signatures = _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(globalProposal, supports_, signatures);
    }
  }

  function _constructForMainchainBridgeManager() internal {
    GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](1);
    address[] memory targets = new address[](1);

    options[0] = GlobalProposal.TargetOption.GatewayContract;
    targets[0] = address(_mainchainGatewayV3);

    // Mainchain Bridge Manager
    _param.mainchainBridgeManager.bridgeContract = address(_mainchainGatewayV3);
    _param.mainchainBridgeManager.callbackRegisters = getEmptyAddressArray();
    _param.mainchainBridgeManager.targetOptions = options;
    _param.mainchainBridgeManager.targets = targets;

    ISharedArgument.BridgeManagerParam memory param = _param.mainchainBridgeManager;
    uint256 length = param.governors.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    {
      // set targets
      GlobalProposal.GlobalProposalDetail memory globalProposal = _mainchainProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: abi.encodeCall(GlobalCoreGovernance.updateManyTargetOption, (param.targetOptions, param.targets)),
        gasAmount: 500_000,
        nonce: _mainchainNonce++
      });

      SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _mainchainBridgeManager.relayGlobalProposal(globalProposal, supports_, signatures);
    }
    {
      // set bridge contract
      GlobalProposal.GlobalProposalDetail memory globalProposal = _mainchainProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE, param.bridgeContract)),
        gasAmount: 500_000,
        nonce: _mainchainNonce++
      });

      SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _mainchainBridgeManager.relayGlobalProposal(globalProposal, supports_, signatures);
    }
    {
      address[] memory callbacks = new address[](1);
      callbacks[0] = address(_mainchainGatewayV3);

      // set gateway contract as callback
      GlobalProposal.GlobalProposalDetail memory globalProposal = _mainchainProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: abi.encodeCall(IBridgeManagerCallbackRegister.registerCallbacks, (callbacks)),
        gasAmount: 500_000,
        nonce: _mainchainNonce++
      });

      SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _mainchainBridgeManager.relayGlobalProposal(globalProposal, supports_, signatures);
    }
  }

  function _mainchainGatewayV3Initialize() internal {
    (address[] memory mainchainTokens, address[] memory roninTokens) = _getMainchainAndRoninTokens();
    uint256 tokenNum = mainchainTokens.length;
    uint256[] memory highTierThreshold = new uint256[](tokenNum);
    uint256[] memory lockedThreshold = new uint256[](tokenNum);
    uint256[] memory unlockFeePercentages = new uint256[](tokenNum);
    uint256[] memory dailyWithdrawalLimits = new uint256[](tokenNum);

    highTierThreshold[0] = 10 ether;
    lockedThreshold[0] = 20 ether;
    unlockFeePercentages[0] = 10_0000; // 10%
    dailyWithdrawalLimits[0] = 12 ether;

    highTierThreshold[1] = highTierThreshold[2] = highTierThreshold[3] = 100_000_000;
    lockedThreshold[1] = lockedThreshold[2] = lockedThreshold[3] = 200_000_000;
    unlockFeePercentages[1] = unlockFeePercentages[2] = unlockFeePercentages[3] = 10_0000; // 10%
    dailyWithdrawalLimits[1] = dailyWithdrawalLimits[2] = dailyWithdrawalLimits[3] = 120_000_000;

    Token.Standard[] memory standards = new Token.Standard[](tokenNum);
    for (uint256 i; i < tokenNum; i++) {
      standards[i] = Token.Standard.ERC20;
    }

    // Mainchain Gateway V3
    _param.mainchainGatewayV3.addresses[0] = mainchainTokens;
    _param.mainchainGatewayV3.addresses[1] = roninTokens;
    _param.mainchainGatewayV3.addresses[2] = getEmptyAddressArray();
    _param.mainchainGatewayV3.thresholds[0] = highTierThreshold;
    _param.mainchainGatewayV3.thresholds[1] = lockedThreshold;
    _param.mainchainGatewayV3.thresholds[2] = unlockFeePercentages;
    _param.mainchainGatewayV3.thresholds[3] = dailyWithdrawalLimits;
    _param.mainchainGatewayV3.standards = standards;
    _param.mainchainGatewayV3.wrappedToken = address(_mainchainWeth);

    ISharedArgument.MainchainGatewayV3Param memory param = _param.mainchainGatewayV3;

    _mainchainGatewayV3.initialize(
      param.roleSetter,
      IWETH(param.wrappedToken),
      param.roninChainId,
      param.numerator,
      param.highTierVWNumerator,
      param.denominator,
      param.addresses,
      param.thresholds,
      param.standards
    );

    _mainchainGatewayV3.initializeV2(address(_mainchainBridgeManager));
    _mainchainGatewayV3.initializeV3(_param.mainchainBridgeManager.bridgeOperators, _param.mainchainBridgeManager.voteWeights);
  }

  function _deployGeneralConfig() internal {
    vm.makePersistent(LibSharedAddress.CONFIG);
    vm.allowCheatcodes(LibSharedAddress.CONFIG);
    deployCodeTo("GeneralConfig.sol", type(GeneralConfig).creationCode, LibSharedAddress.CONFIG);
    _config = IGeneralConfig(LibSharedAddress.CONFIG);
  }

  function _generateSignaturesFor(
    Transfer.Receipt memory receipt,
    uint256[] memory signerPKs,
    bytes32 domainSeparator
  ) internal pure returns (SignatureConsumer.Signature[] memory sigs) {
    sigs = new SignatureConsumer.Signature[](signerPKs.length);

    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, receipt.hash()));

      sigs[i] = _sign(signerPKs[i], digest);
    }
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (SignatureConsumer.Signature memory sig) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig.v = v;
    sig.r = r;
    sig.s = s;
  }
}
