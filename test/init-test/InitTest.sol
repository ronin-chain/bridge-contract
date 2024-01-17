// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import "../Base.t.sol";
import "./Structs.sol";

import { DefaultTestConfig } from "./DefaultTestConfig.sol";

import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { MockRoninGatewayV3Extended } from "@ronin/contracts/mocks/ronin/MockRoninGatewayV3Extended.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { AddressArrayUtils } from "@ronin/contracts/libraries/AddressArrayUtils.sol";

contract InitTest is Base_Test {
  address constant DEFAULT_ADDRESS = address(0);

  InitTestInput internal _inputArguments;
  address internal _deployer;
  address internal _proxyAdmin;

  constructor() {
    _inputArguments.roninGeneralConfig = DefaultTestConfig.get().roninGeneralConfig;
    _inputArguments.maintenanceArguments = DefaultTestConfig.get().maintenanceArguments;
    _inputArguments.stakingVestingArguments = DefaultTestConfig.get().stakingVestingArguments;
    _inputArguments.slashIndicatorArguments = DefaultTestConfig.get().slashIndicatorArguments;
    _inputArguments.roninValidatorSetArguments = DefaultTestConfig.get().roninValidatorSetArguments;
    _inputArguments.governanceAdminArguments = DefaultTestConfig.get().governanceAdminArguments;
    _inputArguments.bridgeRewardArguments = DefaultTestConfig.get().bridgeRewardArguments;

    setRoninGatewayArgs(DefaultTestConfig.get().roninGatewayV3Arguments);
    setMainchainGatewayArgs(DefaultTestConfig.get().mainchainGatewayV3Arguments);
    setBridgeManagerArgs(DefaultTestConfig.get().bridgeManagerArguments);
    setRoninTrustedOrgArgs(DefaultTestConfig.get().roninTrustedOrganizationArguments);
  }

  function setRoninGatewayArgs(RoninGatewayV3Arguments memory arg) public {
    _inputArguments.roninGatewayV3Arguments.roleSetter = arg.roleSetter;
    _inputArguments.roninGatewayV3Arguments.numerator = arg.numerator;
    _inputArguments.roninGatewayV3Arguments.denominator = arg.denominator;
    _inputArguments.roninGatewayV3Arguments.trustedNumerator = arg.trustedNumerator;
    _inputArguments.roninGatewayV3Arguments.trustedDenominator = arg.trustedDenominator;

    delete _inputArguments.roninGatewayV3Arguments.withdrawalMigrators;
    for (uint256 i; i < arg.withdrawalMigrators.length; i++) {
      _inputArguments.roninGatewayV3Arguments.withdrawalMigrators.push(arg.withdrawalMigrators[i]);
    }
    for (uint256 index; index < 2; index++) {
      delete _inputArguments.roninGatewayV3Arguments.packedAddresses[index];
      for (uint256 i; i < arg.packedAddresses[index].length; i++) {
        _inputArguments.roninGatewayV3Arguments.packedAddresses[index].push(arg.packedAddresses[index][i]);
      }

      delete _inputArguments.roninGatewayV3Arguments.packedNumbers[index];
      for (uint256 i; i < arg.packedNumbers[index].length; i++) {
        _inputArguments.roninGatewayV3Arguments.packedNumbers[index].push(arg.packedNumbers[index][i]);
      }
    }

    delete _inputArguments.roninGatewayV3Arguments.standards;
    for (uint256 i; i < arg.standards.length; i++) {
      _inputArguments.roninGatewayV3Arguments.standards.push(arg.standards[i]);
    }
  }

  function setMainchainGatewayArgs(MainchainGatewayV3Arguments memory arg) public {
    _inputArguments.mainchainGatewayV3Arguments.roleSetter = arg.roleSetter;
    _inputArguments.mainchainGatewayV3Arguments.wrappedToken = arg.wrappedToken;
    _inputArguments.mainchainGatewayV3Arguments.numerator = arg.numerator;
    _inputArguments.mainchainGatewayV3Arguments.highTierVWNumerator = arg.highTierVWNumerator;
    _inputArguments.mainchainGatewayV3Arguments.denominator = arg.denominator;

    for (uint256 index; index < 3; index++) {
      delete _inputArguments.mainchainGatewayV3Arguments.addresses[index];
      for (uint256 i; i < arg.addresses[index].length; i++) {
        _inputArguments.mainchainGatewayV3Arguments.addresses[index].push(arg.addresses[index][i]);
      }
    }

    for (uint256 index; index < 3; index++) {
      delete _inputArguments.mainchainGatewayV3Arguments.thresholds[index];
      for (uint256 i; i < arg.thresholds[index].length; i++) {
        _inputArguments.mainchainGatewayV3Arguments.thresholds[index].push(arg.thresholds[index][i]);
      }
    }

    delete _inputArguments.mainchainGatewayV3Arguments.standards;
    for (uint256 i; i < arg.standards.length; i++) {
      _inputArguments.mainchainGatewayV3Arguments.standards.push(arg.standards[i]);
    }
  }

  function setBridgeManagerArgs(BridgeManagerArguments memory arg) public {
    _inputArguments.bridgeManagerArguments.denominator = arg.denominator;
    _inputArguments.bridgeManagerArguments.numerator = arg.numerator;
    _inputArguments.bridgeManagerArguments.expiryDuration = arg.expiryDuration;

    delete _inputArguments.bridgeManagerArguments.members;
    for (uint256 i; i < arg.members.length; i++) {
      _inputArguments.bridgeManagerArguments.members.push(arg.members[i]);
    }
    delete _inputArguments.bridgeManagerArguments.targets;
    for (uint256 i; i < arg.targets.length; i++) {
      _inputArguments.bridgeManagerArguments.targets.push(arg.targets[i]);
    }
  }

  function setRoninTrustedOrgArgs(RoninTrustedOrganizationArguments memory arg) public {
    _inputArguments.roninTrustedOrganizationArguments.denominator = arg.denominator;
    _inputArguments.roninTrustedOrganizationArguments.numerator = arg.numerator;

    delete _inputArguments.roninTrustedOrganizationArguments.trustedOrganizations;
    for (uint256 i; i < arg.trustedOrganizations.length; i++) {
      _inputArguments.roninTrustedOrganizationArguments.trustedOrganizations.push(arg.trustedOrganizations[i]);
    }
  }

  function init() public returns (InitTestOutput memory output) {
    _deployer = makeAddr("deployer");
    vm.deal(_deployer, _inputArguments.bridgeRewardArguments.topupAmount);
    _proxyAdmin = makeAddr("proxyAdmin");

    _prepareAddressForGeneralConfig();

    vm.startPrank(_deployer);
    output.roninGatewayV3Address = payable(_deployRoninGatewayV3Contract());
    output.mainchainGatewayV3Address = payable(_deployMainchainGatewayV3());
    output.bridgeTrackingAddress = payable(_deployBridgeTracking());
    output.bridgeSlashAddress = payable(_deployBridgeSlash());
    output.bridgeRewardAddress = payable(_deployBridgeReward());
    output.roninBridgeManagerAddress = payable(_deployRoninBridgeManager());
    output.mainchainBridgeManagerAddress = payable(_deployMainchainBridgeManager());
    vm.stopPrank();
  }

  function _prepareAddressForGeneralConfig() internal {
    uint256 nonce = 1;
    _inputArguments.roninGeneralConfig.bridgeContract = _calculateAddress(_deployer, nonce).addr;
    nonce += 2;
    _inputArguments.mainchainGeneralConfig.bridgeContract = _calculateAddress(_deployer, nonce).addr;

    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeTrackingContract = _calculateAddress(_deployer, nonce);
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeSlashContract = _calculateAddress(_deployer, nonce);
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeRewardContract = _calculateAddress(_deployer, nonce);

    nonce += 1;
    _inputArguments.roninGeneralConfig.bridgeManagerContract = _calculateAddress(_deployer, nonce);
    nonce += 1;
    _inputArguments.mainchainGeneralConfig.bridgeManagerContract = _calculateAddress(_deployer, nonce);

    console2.log("Deployer", _deployer);
    console2.log(" > roninGateway", _inputArguments.roninGeneralConfig.bridgeContract);
    console2.log(" > mainchainGateway", _inputArguments.mainchainGeneralConfig.bridgeContract);
    console2.log(" > bridgeTrackingContract", _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr);
    console2.log(" > bridgeSlashContract", _inputArguments.roninGeneralConfig.bridgeSlashContract.addr);
    console2.log(" > bridgeRewardContract", _inputArguments.roninGeneralConfig.bridgeRewardContract.addr);
    console2.log(" > roninBridgeManagerContract", _inputArguments.roninGeneralConfig.bridgeManagerContract.addr);
    console2.log(" > mainchainBridgeManagerContract", _inputArguments.mainchainGeneralConfig.bridgeContract);
  }

  function _deployRoninGatewayV3Contract() internal returns (address) {
    MockRoninGatewayV3Extended logic = new MockRoninGatewayV3Extended();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(
      address(logic),
      _proxyAdmin,
      abi.encodeCall(
        RoninGatewayV3.initialize,
        (
          _inputArguments.roninGatewayV3Arguments.roleSetter,
          _inputArguments.roninGatewayV3Arguments.numerator,
          _inputArguments.roninGatewayV3Arguments.denominator,
          _inputArguments.roninGatewayV3Arguments.trustedNumerator,
          _inputArguments.roninGatewayV3Arguments.trustedDenominator,
          _inputArguments.roninGatewayV3Arguments.withdrawalMigrators,
          _inputArguments.roninGatewayV3Arguments.packedAddresses,
          _inputArguments.roninGatewayV3Arguments.packedNumbers,
          _inputArguments.roninGatewayV3Arguments.standards
        )
      )
    );
    address roninGatewayContract = address(proxy);
    vm.label(roninGatewayContract, "RoninGatewayV3");
    assertEq(roninGatewayContract, _inputArguments.roninGeneralConfig.bridgeContract);
    return roninGatewayContract;
  }

  function _deployBridgeTracking() internal returns (address) {
    BridgeTracking logic = new BridgeTracking();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(
      address(logic),
      _inputArguments.roninGeneralConfig.bridgeManagerContract.addr,
      abi.encodeCall(
        BridgeTracking.initialize,
        (
          _inputArguments.roninGeneralConfig.bridgeContract,
          _inputArguments.roninGeneralConfig.validatorContract.addr,
          _inputArguments.roninGeneralConfig.startedAtBlock
        )
      )
    );
    address result = address(proxy);
    vm.label(result, "BridgeTrackingProxy");
    assertEq(result, _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr);
    return result;
  }

  function _deployBridgeSlash() internal returns (address) {
    BridgeSlash logic = new BridgeSlash();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(
      address(logic),
      _inputArguments.roninGeneralConfig.bridgeManagerContract.addr,
      abi.encodeCall(
        BridgeSlash.initialize,
        (
          _inputArguments.roninGeneralConfig.validatorContract.addr,
          _inputArguments.roninGeneralConfig.bridgeManagerContract.addr,
          _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr,
          _inputArguments.roninGeneralConfig.governanceAdmin.addr
        )
      )
    );
    address result = address(proxy);
    vm.label(result, "BridgeSlashProxy");
    assertEq(result, _inputArguments.roninGeneralConfig.bridgeSlashContract.addr);
    return result;
  }

  function _deployBridgeReward() internal returns (address) {
    BridgeReward logic = new BridgeReward();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2{
      value: _inputArguments.bridgeRewardArguments.topupAmount
    }(
      address(logic),
      _inputArguments.roninGeneralConfig.bridgeManagerContract.addr,
      abi.encodeCall(
        BridgeReward.initialize,
        (
          _inputArguments.roninGeneralConfig.bridgeManagerContract.addr,
          _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr,
          _inputArguments.roninGeneralConfig.bridgeSlashContract.addr,
          _inputArguments.roninGeneralConfig.validatorContract.addr,
          _inputArguments.roninGeneralConfig.governanceAdmin.addr,
          _inputArguments.bridgeRewardArguments.rewardPerPeriod
        )
      )
    );
    address result = address(proxy);
    vm.label(result, "BridgeRewardProxy");
    assertEq(result, _inputArguments.roninGeneralConfig.bridgeRewardContract.addr);
    return result;
  }

  function _deployRoninBridgeManager() internal returns (address) {
    uint256 lengthMembers = _inputArguments.bridgeManagerArguments.members.length;
    address[] memory operators = new address[](lengthMembers);
    address[] memory governors = new address[](lengthMembers);
    uint96[] memory weights = new uint96[](lengthMembers);

    for (uint256 i; i < lengthMembers; i++) {
      operators[i] = _inputArguments.bridgeManagerArguments.members[i].operator;
      governors[i] = _inputArguments.bridgeManagerArguments.members[i].governor;
      weights[i] = _inputArguments.bridgeManagerArguments.members[i].weight;
    }

    GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](4);
    address[] memory targets = new address[](4);

    options[0] = GlobalProposal.TargetOption.GatewayContract;
    targets[0] = _inputArguments.roninGeneralConfig.bridgeContract;

    options[1] = GlobalProposal.TargetOption.BridgeReward;
    targets[1] = _inputArguments.roninGeneralConfig.bridgeRewardContract.addr;

    options[2] = GlobalProposal.TargetOption.BridgeSlash;
    targets[2] = _inputArguments.roninGeneralConfig.bridgeSlashContract.addr;

    options[3] = GlobalProposal.TargetOption.BridgeTracking;
    targets[3] = _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr;

    RoninBridgeManager bridgeManager = new RoninBridgeManager(
      _inputArguments.bridgeManagerArguments.numerator,
      _inputArguments.bridgeManagerArguments.denominator,
      _inputArguments.roninGeneralConfig.roninChainId,
      _inputArguments.bridgeManagerArguments.expiryDuration,
      _inputArguments.roninGeneralConfig.bridgeContract,
      wrapAddress(_inputArguments.roninGeneralConfig.bridgeSlashContract.addr),
      operators,
      governors,
      weights,
      options,
      targets
    );

    address result = address(bridgeManager);
    vm.label(result, "RoninBridgeManager");
    assertEq(result, _inputArguments.roninGeneralConfig.bridgeManagerContract.addr);
    return result;
  }

  function _deployMainchainBridgeManager() internal returns (address) {
    uint256 lengthMembers = _inputArguments.bridgeManagerArguments.members.length;
    address[] memory operators = new address[](lengthMembers);
    address[] memory governors = new address[](lengthMembers);
    uint96[] memory weights = new uint96[](lengthMembers);

    for (uint256 i; i < lengthMembers; i++) {
      operators[i] = _inputArguments.bridgeManagerArguments.members[i].operator;
      governors[i] = _inputArguments.bridgeManagerArguments.members[i].governor;
      weights[i] = _inputArguments.bridgeManagerArguments.members[i].weight;
    }

    GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](1);
    address[] memory targets = new address[](1);
    options[0] = GlobalProposal.TargetOption.GatewayContract;
    targets[0] = _inputArguments.mainchainGeneralConfig.bridgeContract;

    MainchainBridgeManager bridgeManager = new MainchainBridgeManager(
      _inputArguments.bridgeManagerArguments.numerator,
      _inputArguments.bridgeManagerArguments.denominator,
      _inputArguments.mainchainGeneralConfig.roninChainId,
      _inputArguments.mainchainGeneralConfig.bridgeContract,
      getEmptyAddressArray(),
      operators,
      governors,
      weights,
      options,
      targets
    );
    vm.label(address(bridgeManager), "MainchainBridgeManager");
    return address(bridgeManager);
  }

  function _deployMainchainGatewayV3() internal returns (address) {
    MainchainGatewayV3 logic = new MainchainGatewayV3();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(
      address(logic),
      _proxyAdmin,
      abi.encodeCall(
        MainchainGatewayV3.initialize,
        (
          _inputArguments.mainchainGatewayV3Arguments.roleSetter,
          _inputArguments.mainchainGatewayV3Arguments.wrappedToken,
          _inputArguments.mainchainGatewayV3Arguments.roninChainId,
          _inputArguments.mainchainGatewayV3Arguments.numerator,
          _inputArguments.mainchainGatewayV3Arguments.highTierVWNumerator,
          _inputArguments.mainchainGatewayV3Arguments.denominator,
          _inputArguments.mainchainGatewayV3Arguments.addresses,
          _inputArguments.mainchainGatewayV3Arguments.thresholds,
          _inputArguments.mainchainGatewayV3Arguments.standards
        )
      )
    );
    address mainchainGatewayContract = address(proxy);
    vm.label(mainchainGatewayContract, "MainchainGatewayV3");
    assertEq(mainchainGatewayContract, _inputArguments.mainchainGeneralConfig.bridgeContract);
    return mainchainGatewayContract;
  }

  function _calculateAddress(address deployer, uint256 nonce) internal pure returns (AddressExtended memory rs) {
    rs.nonce = nonce;
    rs.addr = computeCreateAddress(deployer, nonce);
  }

  function _calculateSalt(uint256 nonce) internal pure returns (bytes32) {
    return keccak256(abi.encode(uint256(nonce)));
  }
}
