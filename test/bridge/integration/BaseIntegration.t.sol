// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
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
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { IWETH } from "@ronin/contracts/interfaces/IWETH.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalCoreGovernance } from "@ronin/contracts/extensions/sequential-governance/GlobalCoreGovernance.sol";
import { IHasContracts } from "@ronin/contracts/interfaces/collections/IHasContracts.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { MockValidatorContract_OnlyTiming_ForHardhatTest } from
  "@ronin/contracts/mocks/ronin/MockValidatorContract_OnlyTiming_ForHardhatTest.sol";
import { PauseEnforcer } from "@ronin/contracts/ronin/gateway/PauseEnforcer.sol";
import { IPauseTarget } from "@ronin/contracts/interfaces/IPauseTarget.sol";
import { GatewayV3 } from "@ronin/contracts/extensions/GatewayV3.sol";
import { IBridgeManagerCallbackRegister } from "@ronin/contracts/interfaces/bridge/IBridgeManagerCallbackRegister.sol";

import { RoninBridgeManagerDeploy } from "@ronin/script/contracts/RoninBridgeManagerDeploy.s.sol";
import { RoninGatewayV3Deploy } from "@ronin/script/contracts/RoninGatewayV3Deploy.s.sol";
import { BridgeTrackingDeploy } from "@ronin/script/contracts/BridgeTrackingDeploy.s.sol";
import { BridgeSlashDeploy } from "@ronin/script/contracts/BridgeSlashDeploy.s.sol";
import { BridgeRewardDeploy } from "@ronin/script/contracts/BridgeRewardDeploy.s.sol";
import { RoninPauseEnforcerDeploy } from "@ronin/script/contracts/RoninPauseEnforcerDeploy.s.sol";

import { MainchainGatewayV3Deploy } from "@ronin/script/contracts/MainchainGatewayV3Deploy.s.sol";
import { MainchainBridgeManagerDeploy } from "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import { MainchainPauseEnforcerDeploy } from "@ronin/script/contracts/MainchainPauseEnforcerDeploy.s.sol";
import { WETHDeploy } from "@ronin/script/contracts/token/WETHDeploy.s.sol";
import { WRONDeploy } from "@ronin/script/contracts/token/WRONDeploy.s.sol";
import { AXSDeploy } from "@ronin/script/contracts/token/AXSDeploy.s.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";

import { RoninBridgeAdminUtils } from "test/helpers/RoninBridgeAdminUtils.t.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

contract BaseIntegration_Test is Base_Test {
  IGeneralConfig _config;
  ISharedArgument.SharedParameter _param;

  PauseEnforcer _roninPauseEnforcer;
  RoninBridgeManager _roninBridgeManager;
  RoninGatewayV3 _roninGatewayV3;
  BridgeTracking _bridgeTracking;
  BridgeSlash _bridgeSlash;
  BridgeReward _bridgeReward;

  PauseEnforcer _mainchainPauseEnforcer;
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

  MockValidatorContract_OnlyTiming_ForHardhatTest _validatorSet;

  RoninBridgeAdminUtils _roninProposalUtils;
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function setUp() public virtual {
    _deployGeneralConfig();

    _deployContractsOnRonin();
    _deployContractsOnMainchain();

    _initializeRonin();
    _initializeMainchain();

    _changeAdminOnRonin();
    _changeAdminOnMainchain();

    _configEmergencyPauserForRoninGateway();
    _configEmergencyPauserForMainchainGateway();

    _configBridgeTrackingForRoninGateway();
  }

  function _deployContractsOnRonin() internal {
    _config.createFork(Network.RoninLocal.key());
    _config.switchTo(Network.RoninLocal.key());

    _roninGatewayV3 = new RoninGatewayV3Deploy().run();
    _bridgeTracking = new BridgeTrackingDeploy().run();
    _bridgeSlash = new BridgeSlashDeploy().run();
    _bridgeReward = new BridgeRewardDeploy().run();
    _roninPauseEnforcer = new RoninPauseEnforcerDeploy().run();
    _roninBridgeManager = new RoninBridgeManagerDeploy().run();

    _roninWeth = new WETHDeploy().run();
    _roninWron = new WRONDeploy().run();
    _roninAxs = new AXSDeploy().run();
    _roninSlp = new SLPDeploy().run();
    _roninUsdc = new USDCDeploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _roninProposalUtils = new RoninBridgeAdminUtils(
      _param.test.roninChainId, _param.test.governorPKs, _roninBridgeManager, _param.roninBridgeManager.governors[0]
    );
    _validatorSet = new MockValidatorContract_OnlyTiming_ForHardhatTest(_param.test.numberOfBlocksInEpoch);
  }

  function _deployContractsOnMainchain() internal {
    _config.createFork(Network.EthLocal.key());
    _config.switchTo(Network.EthLocal.key());

    _mainchainPauseEnforcer = new MainchainPauseEnforcerDeploy().run();
    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    _mainchainWeth = new WETHDeploy().run();
    _mainchainWron = new WRONDeploy().run();
    _mainchainAxs = new AXSDeploy().run();
    _mainchainSlp = new SLPDeploy().run();
    _mainchainUsdc = new USDCDeploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _mainchainProposalUtils = new MainchainBridgeAdminUtils(
      _param.test.roninChainId,
      _param.test.governorPKs,
      _mainchainBridgeManager,
      _param.mainchainBridgeManager.governors[0]
    );
  }

  function _initializeRonin() internal {
    _config.switchTo(Network.RoninLocal.key());

    _validatorSet.setCurrentPeriod(block.timestamp / _validatorSet.PERIOD_DURATION() - 2);

    _bridgeRewardInitialize();
    _bridgeTrackingInitialize();
    _bridgeSlashInitialize();
    _roninPauseEnforcerInitialize();
    _roninGatewayV3Initialize();
    _constructForRoninBridgeManager();
  }

  function _initializeMainchain() internal {
    _config.switchTo(Network.EthLocal.key());

    _mainchainPauseEnforcerInitialize();
    _constructForMainchainBridgeManager();
    _mainchainGatewayV3Initialize();
  }

  function _getMainchainAndRoninTokens()
    internal
    view
    returns (address[] memory mainchainTokens, address[] memory roninTokens)
  {
    uint256 tokenNum = 6;
    mainchainTokens = new address[](tokenNum);
    roninTokens = new address[](tokenNum);

    mainchainTokens[0] = address(_mainchainWeth);
    mainchainTokens[1] = address(_mainchainWron);
    mainchainTokens[2] = address(_mainchainAxs);
    mainchainTokens[3] = address(_mainchainSlp);
    mainchainTokens[4] = address(_mainchainUsdc);

    roninTokens[0] = address(_roninWeth);
    roninTokens[1] = address(_roninWron);
    roninTokens[2] = address(_roninAxs);
    roninTokens[3] = address(_roninSlp);
    roninTokens[4] = address(_roninUsdc);
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

    vm.prank(_param.test.dposGA);
    _bridgeReward.initializeREP2();
  }

  function _bridgeTrackingInitialize() internal {
    // Bridge Tracking
    _param.bridgeTracking.validatorContract = address(_validatorSet);
    _param.bridgeTracking.bridgeContract = address(_roninGatewayV3);

    ISharedArgument.BridgeTrackingParam memory param = _param.bridgeTracking;

    _bridgeTracking.initialize(param.bridgeContract, param.validatorContract, param.startedAtBlock);
    // _bridgeTracking.initializeV2(); NOT INITIALIZE V2
    _bridgeTracking.initializeV3(
      address(_roninBridgeManager), address(_bridgeSlash), address(_bridgeReward), _param.test.dposGA
    );
    vm.prank(_param.test.dposGA);
    _bridgeTracking.initializeREP2();
  }

  function _bridgeSlashInitialize() internal {
    // Bridge Slash
    _param.bridgeSlash.validatorContract = address(_validatorSet);
    _param.bridgeSlash.bridgeManagerContract = address(_roninBridgeManager);
    _param.bridgeSlash.bridgeTrackingContract = address(_bridgeTracking);

    ISharedArgument.BridgeSlashParam memory param = _param.bridgeSlash;

    _bridgeSlash.initialize(
      param.validatorContract, param.bridgeManagerContract, param.bridgeTrackingContract, param.dposGA
    );

    vm.prank(_param.test.dposGA);
    _bridgeSlash.initializeREP2();
  }

  function _roninPauseEnforcerInitialize() internal {
    _param.roninPauseEnforcer.target = address(_roninGatewayV3);

    ISharedArgument.PauseEnforcerParam memory param = _param.roninPauseEnforcer;

    _roninPauseEnforcer.initialize(IPauseTarget(param.target), param.admin, param.sentries);
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
        nonce: _roninBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

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
        nonce: _roninBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(globalProposal, supports_, signatures);
    }

    {
      // set callback register
      bytes memory calldata_ =
        abi.encodeCall(IBridgeManagerCallbackRegister.registerCallbacks, (param.callbackRegisters));
      GlobalProposal.GlobalProposalDetail memory globalProposal = _roninProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: calldata_,
        gasAmount: 500_000,
        nonce: _roninBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

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
        nonce: _mainchainBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

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
        nonce: _mainchainBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

      vm.prank(_param.roninBridgeManager.governors[0]);
      _mainchainBridgeManager.relayGlobalProposal(globalProposal, supports_, signatures);
    }

    {
      // set callback register
      bytes memory calldata_ =
        abi.encodeCall(IBridgeManagerCallbackRegister.registerCallbacks, (param.callbackRegisters));
      GlobalProposal.GlobalProposalDetail memory globalProposal = _mainchainProposalUtils.createGlobalProposal({
        expiryTimestamp: block.timestamp + 10,
        targetOption: GlobalProposal.TargetOption.BridgeManager,
        value: 0,
        calldata_: calldata_,
        gasAmount: 500_000,
        nonce: _mainchainBridgeManager.round(0) + 1
      });

      SignatureConsumer.Signature[] memory signatures =
        _mainchainProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

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

    highTierThreshold[0] = 10;
    lockedThreshold[0] = 20;
    unlockFeePercentages[0] = 100_000;
    dailyWithdrawalLimits[0] = 12;

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
  }

  function _mainchainPauseEnforcerInitialize() internal {
    _param.mainchainPauseEnforcer.target = address(_mainchainGatewayV3);

    ISharedArgument.PauseEnforcerParam memory param = _param.mainchainPauseEnforcer;

    _mainchainPauseEnforcer.initialize(IPauseTarget(param.target), param.admin, param.sentries);
  }

  function _changeAdminOnRonin() internal {
    _config.switchTo(Network.RoninLocal.key());

    vm.startPrank(_param.test.proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).changeAdmin(address(_roninBridgeManager));
    TransparentUpgradeableProxyV2(payable(address(_bridgeReward))).changeAdmin(address(_roninBridgeManager));
    TransparentUpgradeableProxyV2(payable(address(_bridgeSlash))).changeAdmin(address(_roninBridgeManager));
    TransparentUpgradeableProxyV2(payable(address(_bridgeTracking))).changeAdmin(address(_roninBridgeManager));
    vm.stopPrank();
  }

  function _changeAdminOnMainchain() internal {
    _config.switchTo(Network.EthLocal.key());

    vm.startPrank(_param.test.proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_mainchainGatewayV3))).changeAdmin(address(_mainchainBridgeManager));
    vm.stopPrank();
  }

  function _configEmergencyPauserForRoninGateway() internal {
    _config.switchTo(Network.RoninLocal.key());

    bytes memory calldata_ = abi.encodeCall(GatewayV3.setEmergencyPauser, (address(_roninPauseEnforcer)));
    _roninProposalUtils.functionDelegateCall(address(_roninGatewayV3), calldata_);
  }

  function _configEmergencyPauserForMainchainGateway() internal {
    _config.switchTo(Network.EthLocal.key());

    bytes memory calldata_ = abi.encodeCall(GatewayV3.setEmergencyPauser, (address(_mainchainPauseEnforcer)));
    _mainchainProposalUtils.functionDelegateCall(address(_mainchainGatewayV3), calldata_);
  }

  function _configBridgeTrackingForRoninGateway() internal {
    _config.switchTo(Network.RoninLocal.key());

    bytes memory calldata_ =
      abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE_TRACKING, address(_bridgeTracking)));
    _roninProposalUtils.functionDelegateCall(address(_roninGatewayV3), calldata_);

    _config.switchTo(Network.EthLocal.key());
  }

  function _deployGeneralConfig() internal {
    vm.makePersistent(LibSharedAddress.CONFIG);
    vm.allowCheatcodes(LibSharedAddress.CONFIG);
    deployCodeTo("GeneralConfig.sol", type(GeneralConfig).creationCode, LibSharedAddress.CONFIG);
    _config = IGeneralConfig(LibSharedAddress.CONFIG);
  }

  function _wrapUpEpochAndMine() internal {
    _wrapUpEpoch();
    // mine a dummy block
    vm.roll(block.number + 1);
  }

  function _wrapUpEpoch() internal {
    uint256 multiplier = _validatorSet.numberOfBlocksInEpoch();
    vm.roll((block.number / multiplier + 1) * multiplier - 1);

    vm.prank(block.coinbase);
    _validatorSet.wrapUpEpoch();
  }

  function _setTimestampToPeriodEnding() internal {
    vm.warp(((block.timestamp / 1 days) + 1) * 1 days);
  }
}
