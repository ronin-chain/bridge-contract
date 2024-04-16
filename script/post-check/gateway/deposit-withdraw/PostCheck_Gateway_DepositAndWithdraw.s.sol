// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { Vm, VmSafe } from "forge-std/Vm.sol";
import { BasePostCheck } from "script/post-check/BasePostCheck.s.sol";
import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Transfer as LibTransfer } from "@ronin/contracts/libraries/Transfer.sol";
import { TNetwork, Network } from "script/utils/Network.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Proposal, LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { IRoninGatewayV3, RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { IMainchainGatewayV3, MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { HasContracts } from "@ronin/contracts/extensions/collections/HasContracts.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";

abstract contract PostCheck_Gateway_DepositAndWithdraw is BasePostCheck, SignatureConsumer {
  using LibProxy for *;
  using LibArray for *;
  using LibProposal for *;
  using stdStorage for StdStorage;
  using LibCompanionNetwork for *;
  using LibTransfer for LibTransfer.Request;
  using LibTransfer for LibTransfer.Receipt;

  address private user = makeAddr("user");
  uint256 private quantity;

  LibTransfer.Request depositRequest;
  LibTransfer.Request withdrawRequest;

  MockERC20 private roninERC20;
  MockERC20 private mainchainERC20;

  address[] private roninTokens;
  address[] private mainchainTokens;
  TokenStandard[] private standards = [TokenStandard.ERC20];

  uint256 private roninChainId;
  uint256 private mainchainChainId;

  TNetwork private currentNetwork;
  TNetwork private companionNetwork;

  function _setUp() private onlyOnRoninNetworkOrLocal {
    console.log("RoninBridgeManager", roninBridgeManager);
    console.log("MainchainBridgeManager", mainchainBridgeManager);

    console.log("RoninGateway", roninGateway);
    console.log("MainchainGateway", mainchainGateway);

    _setUpOnRonin();
    _setUpOnMainchain();
    _mapTokenRonin();
    _mapTokenMainchain();
  }

  function _mapTokenRonin() private {
    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = network().companionChainId();
    address admin = roninGateway.getProxyAdmin();
    console.log("Admin", admin);
    vm.prank(address(admin));
    TransparentUpgradeableProxyV2(payable(address(roninGateway))).functionDelegateCall(
      abi.encodeCall(RoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards))
    );
  }

  function _mapTokenMainchain() private {
    (, companionNetwork) = network().companionNetworkData();
    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](1);
    thresholds[0][0] = 200_000_000 ether;
    thresholds[1] = new uint256[](1);
    thresholds[1][0] = 800_000_000 ether;
    thresholds[2] = new uint256[](1);
    thresholds[2][0] = 10;
    thresholds[3] = new uint256[](1);
    thresholds[3][0] = 500_000_000 ether;

    console.log("Mainchain Gateway", address(mainchainGateway));
    address admin = mainchainGateway.getProxyAdmin();
    console.log("Admin", admin);

    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(mainchainGateway))).functionDelegateCall(
      abi.encodeCall(MainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds))
    );

    CONFIG.switchTo(currentNetwork);
  }

  function _setUpOnRonin() private {
    roninERC20 = new MockERC20("RoninERC20", "RERC20");
    // roninERC20.initialize("RoninERC20", "RERC20", 18);
    roninTokens.push(address(roninERC20));
    roninChainId = block.chainid;
    currentNetwork = network();

    cheatAddOverWeightedGovernor(address(roninBridgeManager));

    vm.deal(user, 10 ether);
    deal(address(roninERC20), user, 1000 ether);
  }

  function _setUpOnMainchain() private {
    (, companionNetwork) = network().companionNetworkData();
    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    mainchainChainId = block.chainid;
    gwDomainSeparator = MainchainGatewayV3(payable(mainchainGateway)).DOMAIN_SEPARATOR();

    cheatAddOverWeightedGovernor(address(mainchainBridgeManager));

    mainchainERC20 = new MockERC20("MainchainERC20", "MERC20");
    // mainchainERC20.initialize("MainchainERC20", "MERC20", 18);
    mainchainTokens.push(address(mainchainERC20));

    vm.deal(user, 10 ether);
    deal(address(mainchainERC20), user, 1000 ether);

    CONFIG.switchTo(currentNetwork);
  }

  function _validate_Gateway_DepositAndWithdraw() internal onlyOnRoninNetworkOrLocal {
    _setUp();
    validate_HasBridgeManager();
    validate_Gateway_depositERC20();
    validate_Gateway_withdrawERC20();
  }

  function validate_HasBridgeManager() internal onPostCheck("validate_HasBridgeManager") {
    assertEq(roninBridgeManager.getProxyAdmin(), roninBridgeManager, "Invalid ProxyAdmin in RoninBridgeManager, expected self");
    assertEq(HasContracts(roninGateway).getContract(ContractType.BRIDGE_MANAGER), roninBridgeManager, "Invalid RoninBridgeManager in roninGateway");
    assertEq(HasContracts(bridgeTracking).getContract(ContractType.BRIDGE_MANAGER), roninBridgeManager, "Invalid RoninBridgeManager in bridgeTracking");
    assertEq(HasContracts(bridgeReward).getContract(ContractType.BRIDGE_MANAGER), roninBridgeManager, "Invalid RoninBridgeManager in bridgeReward");
    assertEq(HasContracts(bridgeSlash).getContract(ContractType.BRIDGE_MANAGER), roninBridgeManager, "Invalid RoninBridgeManager in bridgeSlash");

    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    assertEq(mainchainBridgeManager.getProxyAdmin(), mainchainBridgeManager, "Invalid MainchainBridgeManager in mainchainBridgeManager");
    assertEq(
      HasContracts(mainchainGateway).getContract(ContractType.BRIDGE_MANAGER), mainchainBridgeManager, "Invalid MainchainBridgeManager in mainchainGateway"
    );

    CONFIG.switchTo(currentNetwork);
  }

  function validate_Gateway_depositERC20() private onPostCheck("validate_Gateway_depositERC20") {
    depositRequest.recipientAddr = makeAddr("ronin-recipient");
    depositRequest.tokenAddr = address(mainchainERC20);
    depositRequest.info.erc = TokenStandard.ERC20;
    depositRequest.info.id = 0;
    depositRequest.info.quantity = 100 ether;

    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    vm.prank(user);
    mainchainERC20.approve(address(mainchainGateway), 100 ether);
    vm.prank(user);
    vm.recordLogs();
    MainchainGatewayV3(mainchainGateway).requestDepositFor(depositRequest);

    VmSafe.Log[] memory logs = vm.getRecordedLogs();
    LibTransfer.Receipt memory receipt;
    bytes32 receiptHash;
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].emitter == address(mainchainGateway) && logs[i].topics[0] == IMainchainGatewayV3.DepositRequested.selector) {
        (receiptHash, receipt) = abi.decode(logs[i].data, (bytes32, LibTransfer.Receipt));
      }
    }

    CONFIG.switchTo(currentNetwork);

    vm.prank(cheatOperator);
    RoninGatewayV3(roninGateway).depositFor(receipt);

    assertEq(roninERC20.balanceOf(depositRequest.recipientAddr), 100 ether);
  }

  function validate_Gateway_withdrawERC20() private onPostCheck("validate_Gateway_withdrawERC20") {
    withdrawRequest.recipientAddr = makeAddr("mainchain-recipient");
    withdrawRequest.tokenAddr = address(roninERC20);
    withdrawRequest.info.erc = TokenStandard.ERC20;
    withdrawRequest.info.id = 0;
    withdrawRequest.info.quantity = 100 ether;

    // uint256 _numOperatorsForVoteExecuted = (RoninBridgeManager(_manager[block.chainid]).minimumVoteWeight() - 1) / 100 + 1;
    vm.prank(user);
    roninERC20.approve(address(roninGateway), 100 ether);
    vm.prank(user);
    vm.recordLogs();
    RoninGatewayV3(payable(address(roninGateway))).requestWithdrawalFor(withdrawRequest, mainchainChainId);

    VmSafe.Log[] memory logs = vm.getRecordedLogs();
    LibTransfer.Receipt memory receipt;
    bytes32 receiptHash;
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].emitter == address(roninGateway) && logs[i].topics[0] == IRoninGatewayV3.WithdrawalRequested.selector) {
        (receiptHash, receipt) = abi.decode(logs[i].data, (bytes32, LibTransfer.Receipt));
      }
    }

    bytes32 receiptDigest = LibTransfer.receiptDigest(gwDomainSeparator, receiptHash);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(cheatOperatorPk, receiptDigest);

    Signature[] memory sigs = new Signature[](1);
    sigs[0] = Signature(v, r, s);

    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    MainchainGatewayV3(payable(mainchainGateway)).submitWithdrawal(receipt, sigs);

    assertEq(mainchainERC20.balanceOf(withdrawRequest.recipientAddr), 100 ether);

    CONFIG.switchTo(currentNetwork);
  }

  // Set the balance of an account for any ERC20 token
  // Use the alternative signature to update `totalSupply`
  function deal(address token, address to, uint256 give) internal virtual {
    deal(token, to, give, false);
  }

  function deal(address token, address to, uint256 give, bool adjust) internal virtual {
    // get current balance
    (, bytes memory balData) = token.staticcall(abi.encodeWithSelector(0x70a08231, to));
    uint256 prevBal = abi.decode(balData, (uint256));

    // update balance
    stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(give);

    // update total supply
    if (adjust) {
      (, bytes memory totSupData) = token.staticcall(abi.encodeWithSelector(0x18160ddd));
      uint256 totSup = abi.decode(totSupData, (uint256));
      if (give < prevBal) {
        totSup -= (prevBal - give);
      } else {
        totSup += (give - prevBal);
      }
      stdstore.target(token).sig(0x18160ddd).checked_write(totSup);
    }
  }
}
