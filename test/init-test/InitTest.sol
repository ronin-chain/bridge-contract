// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/console2.sol";
import "../Base.t.sol";
import "./Structs.sol";

import {DefaultTestConfig} from "./DefaultTestConfig.sol";

import {TransparentUpgradeableProxyV2} from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import {BridgeTracking} from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import {BridgeSlash} from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import {BridgeReward} from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import {RoninBridgeManager} from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import {MainchainBridgeManager} from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import {MockBridge} from "@ronin/contracts/mocks/MockBridge.sol";

contract InitTest is Base_Test {
  InitTestInput internal _inputArguments;

  constructor() {
    _inputArguments.roninGeneralConfig = DefaultTestConfig.get().roninGeneralConfig;
    _inputArguments.maintenanceArguments = DefaultTestConfig.get().maintenanceArguments;
    _inputArguments.stakingVestingArguments = DefaultTestConfig.get().stakingVestingArguments;
    _inputArguments.slashIndicatorArguments = DefaultTestConfig.get().slashIndicatorArguments;
    _inputArguments.roninValidatorSetArguments = DefaultTestConfig.get().roninValidatorSetArguments;
    _inputArguments.governanceAdminArguments = DefaultTestConfig.get().governanceAdminArguments;
    _inputArguments.bridgeRewardArguments = DefaultTestConfig.get().bridgeRewardArguments;

    setBridgeManagerArgs(DefaultTestConfig.get().bridgeManagerArguments);
    setRoninTrustedOrgArgs(DefaultTestConfig.get().roninTrustedOrganizationArguments);
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
    for (uint256 i; i < arg.members.length; i++) {
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
    _prepareAddressForGeneralConfig();

    output.bridgeContractAddress = payable(_deployBridgeContract());
    output.bridgeTrackingAddress = payable(_deployBridgeTracking());
    output.bridgeSlashAddress = payable(_deployBridgeSlash());
    output.bridgeRewardAddress = payable(_deployBridgeReward());
    output.roninBridgeManagerAddress = payable(_deployRoninBridgeManager());
    output.mainchainBridgeManagerAddress = payable(_deployMainchainBridgeManager());
  }

  function _prepareAddressForGeneralConfig() internal {
    uint256 nonce = 0;
    address deployer = address(this);
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeContract = _calculateAddress(deployer, nonce).addr;
    _inputArguments.mainchainGeneralConfig.bridgeContract = _calculateAddress(deployer, nonce).addr;
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeTrackingContract = _calculateAddress(deployer, nonce);
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeSlashContract = _calculateAddress(deployer, nonce);
    nonce += 2;
    _inputArguments.roninGeneralConfig.bridgeRewardContract = _calculateAddress(deployer, nonce);

    nonce += 1;
    _inputArguments.roninGeneralConfig.bridgeManagerContract = _calculateAddress(deployer, nonce);

    // console2.log("Deployer", deployer);
    // console2.log(" > bridgeTrackingContract", _inputArguments.roninGeneralConfig.bridgeTrackingContract.addr);
    // console2.log(" > bridgeSlashContract", _inputArguments.roninGeneralConfig.bridgeSlashContract.addr);
    // console2.log(" > bridgeRewardContract", _inputArguments.roninGeneralConfig.bridgeRewardContract.addr);
    // console2.log(" > bridgeManagerContract", _inputArguments.roninGeneralConfig.bridgeManagerContract.addr);
  }

  function _deployBridgeContract() internal returns (address) {
    MockBridge logic = new MockBridge();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(address(logic), address(this), abi.encode());
    address bridgeContract = address(proxy);
    vm.label(bridgeContract, "BridgeContract");
    return bridgeContract;
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

  function _calculateAddress(address deployer, uint256 nonce) internal pure returns (AddressExtended memory rs) {
    rs.nonce = nonce;
    rs.addr = computeCreateAddress(deployer, nonce);
  }

  function _calculateSalt(uint256 nonce) internal pure returns (bytes32) {
    return keccak256(abi.encode(uint256(nonce)));
  }
}
