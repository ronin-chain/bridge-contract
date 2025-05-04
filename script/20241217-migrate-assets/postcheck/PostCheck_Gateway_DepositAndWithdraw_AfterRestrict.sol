// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { BasePostCheck } from "script/post-check/BasePostCheck.s.sol";
import { MockERC20 } from "src/mocks/token/MockERC20.sol";
import { MockERC721 } from "src/mocks/token/MockERC721.sol";
import { Contract } from "script/utils/Contract.sol";
import { TokenStandard } from "src/libraries/LibTokenInfo.sol";
import { Transfer as LibTransfer } from "src/libraries/Transfer.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { IBridgeManager } from "src/interfaces/bridge/IBridgeManager.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { IRoninGatewayV3 } from "script/interfaces/IRoninGatewayV3.sol";
import { IMainchainGatewayV3 } from "script/interfaces/IMainchainGatewayV3.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IWETH } from "src/interfaces/IWETH.sol";
import { IQuorum } from "src/interfaces/IQuorum.sol";
import { PauseEnforcer } from "src/ronin/gateway/PauseEnforcer.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { IHasContracts } from "src/interfaces/collections/IHasContracts.sol";
import { ContractType } from "src/utils/ContractType.sol";
import { FunctionRestrictable } from "src/extensions/FunctionRestrictable.sol";

abstract contract PostCheck_Gateway_DepositAndWithdraw_AfterRestrict is BasePostCheck {
  using LibProxy for *;
  using LibArray for *;
  using LibCompanionNetwork for *;
  using LibTransfer for LibTransfer.Request;
  using LibTransfer for LibTransfer.Receipt;

  address private user = makeAddr("user");
  uint256 private quantity;

  LibTransfer.Request depositReq;
  LibTransfer.Request withdrawReq;

  MockERC20 private ronERC20;
  MockERC721 private ronERC721;
  MockERC20 private ethERC20;
  MockERC721 private ethERC721;

  address[] private ronTokens = new address[](2);
  address[] private ethTokens = new address[](2);
  TokenStandard[] private standards = [TokenStandard.ERC20, TokenStandard.ERC721];

  uint256 private ronChainId;
  uint256 private ethChainId;

  IWETH private ethWETH;
  MockERC20 private ronWETH;

  TNetwork private currNetwork;
  TNetwork private companionNetwork;

  function _setUp() private onlyOnRoninNetworkOrLocal {
    console.log("RoninBridgeManager", ronBM);
    console.log("MainchainBridgeManager", ethBM);

    console.log("RoninGateway", ronGW);
    console.log("MainchainGateway", ethGW);

    _setUpOnRonin();
    _setUpOnMainchain();
    _mapTokenRonin();
    _mapTokenMainchain();
  }

  function _mapTokenRonin() private {
    uint256[] memory chainIds = new uint256[](2);
    chainIds[0] = network().companionChainId();
    chainIds[1] = chainIds[0];

    address admin = ronGW.getProxyAdmin();
    console.log("Admin for ronin gateway", admin);

    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ronGW).functionDelegateCall(abi.encodeCall(IRoninGatewayV3.mapTokens, (ronTokens, ethTokens, chainIds, standards)));
  }

  function _mapTokenMainchain() private {
    (, companionNetwork) = network().companionNetworkData();
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);

    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](2);
    thresholds[0][0] = 200_000_000 ether;
    thresholds[1] = new uint256[](2);
    thresholds[1][0] = 800_000_000 ether;
    thresholds[2] = new uint256[](2);
    thresholds[2][0] = 10;
    thresholds[3] = new uint256[](2);
    thresholds[3][0] = 500_000_000 ether;

    console.log("Mainchain Gateway", ethGW);
    address admin = ethGW.getProxyAdmin();
    console.log("Admin", admin);

    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ethGW).functionDelegateCall(
      abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (ethTokens, ronTokens, standards, thresholds))
    );

    switchBack(prevNetwork, prevForkId);
  }

  function _setUpOnRonin() private {
    ronERC20 = new MockERC20("RoninERC20", "RERC20");
    ronERC721 = new MockERC721("RoninERC721", "RERC721");

    ronTokens[0] = address(ronERC20);
    ronTokens[1] = address(ronERC721);

    ronChainId = block.chainid;
    currNetwork = network();

    vm.deal(user, 10 ether);
    deal(address(ronERC20), user, 1000 ether);

    ronWETH = MockERC20(loadContract(Contract.WETH.key()));
  }

  function _setUpOnMainchain() private {
    (, companionNetwork) = network().companionNetworkData();
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);

    ethChainId = block.chainid;
    gwDomainHash = IMainchainGatewayV3(ethGW).DOMAIN_SEPARATOR();

    ethERC20 = new MockERC20("MainchainERC20", "MERC20");
    ethERC721 = new MockERC721("MainchainERC721", "MERC721");

    ethTokens[0] = address(ethERC20);
    ethTokens[1] = address(ethERC721);

    ethWETH = IWETH(loadContract(Contract.WETH.key()));

    vm.deal(user, 10 ether);
    deal(address(ethERC20), user, 1000 ether);

    switchBack(prevNetwork, prevForkId);
  }

  function _validate_Gateway_DepositAndWithdraw() internal {
    _setUp();

    validate_Execute_Migration();
    validate_Pause_Unpause_Globally();
    validate_RevertIf_RequestWithdraw_ERC721_RoninGateway();
    validate_RevertIf_RequestDeposit_ERC721();
    validate_RevertIf_Deposit_WETH_MainchainGateway();
    validate_RevertIf_RequestWithdraw_ETH_RoninGateway();
    validate_Gateway_WETHAddressUnchanged();

    validate_HasBridgeManager();
  }

  function validate_Execute_Migration() private onPostCheck("validate_Execute_Migration") onlyOnRoninNetworkOrLocal {
    address[] memory tokens = new address[](2);
    bytes32 migratorRole = keccak256("MIGRATOR_ROLE");

    tokens[0] = 0xF80132FC0A86ADd011BffCe3AedD60A86E3d704D;
    tokens[1] = 0xa8754b9Fa15fc18BB59458815510E40a12cD2014;
    uint256[] memory amounts = new uint256[](2);
    for (uint256 i; i < tokens.length; ++i) {
      amounts[i] = MockERC20(tokens[i]).balanceOf(address(ronGW));
      require(amounts[i] > 0, "No tokens to migrate");
    }

    address migrator = IRoninGatewayV3(ronGW).getRoleMember(migratorRole, 0);
    vm.prank(migrator);
    IRoninGatewayV3(ronGW).migrateERC20(tokens, amounts);

    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 snapshotId = vm.snapshot();

    migrator = IMainchainGatewayV3(ethGW).getRoleMember(migratorRole, 0);
    tokens = new address[](9);
    tokens[0] = 0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b;
    tokens[1] = 0x95b4B8CaD3567B5d7EF7399C2aE1d7070692aB0D;
    tokens[2] = 0x88D100432F98956b16B66Df56962FD3e5cCd297A;
    tokens[3] = 0x540ddE0739EeFAf90D0Ca05aCa90513Ce89E7e79;
    tokens[4] = 0x25f8087EAD173b73D6e8B84329989A8eEA16CF73;
    tokens[5] = 0x94e496474F1725f1c1824cB5BDb92d7691A4F03a;
    tokens[6] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    tokens[7] = address(0);
    tokens[8] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    amounts = new uint256[](9);
    for (uint256 i; i < tokens.length; ++i) {
      if (tokens[i] == address(0)) {
        amounts[i] = ethGW.balance;
      } else {
        amounts[i] = MockERC20(tokens[i]).balanceOf(address(ethGW));
      }
    }

    vm.prank(migrator);
    IMainchainGatewayV3(ethGW).migrateERC20(tokens, amounts);
  }

  function validate_Pause_Unpause_Globally() private onPostCheck("validate_Pause_Unpause_Globally") onlyOnRoninNetworkOrLocal {
    PauseEnforcer pauseEnforcer = PauseEnforcer(IRoninGatewayV3(ronGW).emergencyPauser());
    address sentry = pauseEnforcer.getRoleMember(pauseEnforcer.SENTRY_ROLE(), 0);
    assertTrue(sentry != address(0x0), "No sentry found");
    vm.prank(sentry);
    pauseEnforcer.triggerPause();

    assertTrue(IRoninGatewayV3(ronGW).paused(), "Gateway should be paused");

    vm.prank(sentry);
    pauseEnforcer.triggerUnpause();

    assertTrue(!IRoninGatewayV3(ronGW).paused(), "Gateway should be unpaused");

    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    pauseEnforcer = PauseEnforcer(IMainchainGatewayV3(ethGW).emergencyPauser());
    sentry = pauseEnforcer.getRoleMember(pauseEnforcer.SENTRY_ROLE(), 0);
    assertTrue(sentry != address(0x0), "No sentry found");
    vm.prank(sentry);
    pauseEnforcer.triggerPause();

    assertTrue(IMainchainGatewayV3(ethGW).paused(), "Gateway should be paused");

    vm.prank(sentry);
    pauseEnforcer.triggerUnpause();

    assertTrue(!IMainchainGatewayV3(ethGW).paused(), "Gateway should be unpaused");
  }

  function validate_RevertIf_RequestDeposit_ERC721() private onPostCheck("validate_RevertIf_RequestDeposit_ERC721") onlyOnRoninNetworkOrLocal {
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 snapshotId = vm.snapshot();

    depositReq.recipientAddr = makeAddr("ronin-recipient");
    depositReq.tokenAddr = address(ethERC721);
    depositReq.info.erc = TokenStandard.ERC721;
    depositReq.info.id = 1;

    ethERC721.mint(user, depositReq.info.id);
    vm.prank(user);
    ethERC721.approve(ethGW, depositReq.info.id);

    vm.prank(user);
    vm.recordLogs();
    vm.expectRevert();
    IMainchainGatewayV3(ethGW).requestDepositFor(depositReq);
  }

  function validate_RevertIf_RequestWithdraw_ERC721_RoninGateway()
    private
    onPostCheck("validate_RevertIf_RequestWithdraw_ERC721_RoninGateway")
    onlyOnRoninNetworkOrLocal
  {
    withdrawReq.recipientAddr = makeAddr("mainchain-recipient");
    withdrawReq.tokenAddr = address(ronERC721);
    withdrawReq.info.erc = TokenStandard.ERC721;
    withdrawReq.info.id = 1;

    ronERC721.mint(user, withdrawReq.info.id);
    vm.prank(user);
    ronERC721.approve(ronGW, withdrawReq.info.id);
    vm.prank(user);
    vm.expectRevert();
    IRoninGatewayV3(ronGW).requestWithdrawalFor(withdrawReq, ethChainId);
  }

  function validate_RevertIf_RequestWithdraw_ETH_RoninGateway()
    private
    onPostCheck("validate_RevertIf_RequestWithdraw_ETH_RoninGateway")
    onlyOnRoninNetworkOrLocal
  {
    withdrawReq.recipientAddr = makeAddr("mainchain-recipient");
    withdrawReq.tokenAddr = address(ronWETH);
    withdrawReq.info.erc = TokenStandard.ERC20;
    withdrawReq.info.id = 0;
    withdrawReq.info.quantity = 1 ether;

    if (network() == DefaultNetwork.RoninTestnet.key()) {
      withdrawReq.info.quantity = 0.00009 ether; // Low tier 0.0001
    }

    deal(address(ronWETH), user, withdrawReq.info.quantity);
    vm.prank(user);
    ronWETH.approve(ronGW, withdrawReq.info.quantity);
    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.requestWithdrawalFor.selector, TokenStandard.ERC20));
    IRoninGatewayV3(ronGW).requestWithdrawalFor(withdrawReq, ethChainId);

    // Un-restrict
    address admin = ronGW.getProxyAdmin();
    uint256 snapshotId = vm.snapshot();
    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ronGW).functionDelegateCall(
      abi.encodeCall(FunctionRestrictable.restrict, (IRoninGatewayV3.requestWithdrawalFor.selector, 0))
    );

    vm.prank(user);
    IRoninGatewayV3(ronGW).requestWithdrawalFor(withdrawReq, ethChainId);
    (LibTransfer.Receipt memory receipt, bytes32 receiptHash) = _getReceiptHash(ronGW, IRoninGatewayV3.WithdrawalRequested.selector);

    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 ethSnapshotId = vm.snapshot();

    bytes32 receiptDigest = LibTransfer.receiptDigest(gwDomainHash, receiptHash);

    overrideMockBOs(ethBM);

    uint256 minSigRequired = _calcMinSigOrVoteRequired(ethBM, ethGW);
    assertTrue(minSigRequired > 1, "Invalid test setup");

    Signature[] memory sigs = _bulkSignReceipt(mockOps.slice(0, minSigRequired), receiptDigest);
    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IMainchainGatewayV3.submitWithdrawal.selector, TokenStandard.ERC20));
    vm.prank(user);
    IMainchainGatewayV3(ethGW).submitWithdrawal(receipt, sigs);

    // Un-restrict
    admin = ethGW.getProxyAdmin();
    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ethGW).functionDelegateCall(
      abi.encodeCall(FunctionRestrictable.restrict, (IMainchainGatewayV3.submitWithdrawal.selector, 0))
    );

    vm.prank(user);
    IMainchainGatewayV3(ethGW).submitWithdrawal(receipt, sigs);

    vm.revertTo(ethSnapshotId);

    switchBack(prevNetwork, prevForkId);
    vm.revertTo(snapshotId);
  }

  function validate_RevertIf_Deposit_WETH_MainchainGateway() private onPostCheck("validate_RevertIf_Deposit_WETH_MainchainGateway") onlyOnRoninNetworkOrLocal {
    depositReq.recipientAddr = makeAddr("ronin-recipient");
    depositReq.tokenAddr = address(ethWETH);
    depositReq.info.erc = TokenStandard.ERC20;
    depositReq.info.id = 0;
    depositReq.info.quantity = 1 ether;

    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 snapshotId = vm.snapshot();

    deal(address(ethWETH), user, depositReq.info.quantity);

    vm.prank(user);
    ethWETH.approve(ethGW, depositReq.info.quantity);

    uint256 balBefore = ethGW.balance;

    vm.prank(user);
    vm.recordLogs();
    vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IMainchainGatewayV3.requestDepositFor.selector, TokenStandard.ERC20));
    IMainchainGatewayV3(ethGW).requestDepositFor(depositReq);

    // Un-restrict
    address admin = ethGW.getProxyAdmin();
    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ethGW).functionDelegateCall(
      abi.encodeCall(FunctionRestrictable.restrict, (IMainchainGatewayV3.requestDepositFor.selector, 0))
    );

    vm.prank(user);
    vm.recordLogs();
    IMainchainGatewayV3(ethGW).requestDepositFor(depositReq);

    uint256 balAfter = address(ethGW).balance;
    assertEq(balAfter - balBefore, depositReq.info.quantity, "ETH should be deposited");

    (LibTransfer.Receipt memory receipt,) = _getReceiptHash(ethGW, IMainchainGatewayV3.DepositRequested.selector);

    vm.revertTo(snapshotId);
    switchBack(prevNetwork, prevForkId);

    overrideMockBOs(ronBM);

    uint256 minVoteRequired = _calcMinSigOrVoteRequired(ronBM, ronGW);
    assertTrue(minVoteRequired > 1, "Invalid test setup");

    for (uint256 i; i < minVoteRequired; ++i) {
      vm.prank(mockOps[i]);
      vm.expectRevert(abi.encodeWithSelector(FunctionRestrictable.ErrRestricted.selector, IRoninGatewayV3.depositFor.selector, TokenStandard.ERC20));
      IRoninGatewayV3(ronGW).depositFor(receipt);
    }

    // Un-restrict
    admin = ronGW.getProxyAdmin();
    vm.prank(admin);
    ITransparentUpgradeableProxyV2(ronGW).functionDelegateCall(abi.encodeCall(FunctionRestrictable.restrict, (IRoninGatewayV3.depositFor.selector, 0)));

    for (uint256 i; i < minVoteRequired; ++i) {
      vm.prank(mockOps[i]);
      IRoninGatewayV3(ronGW).depositFor(receipt);
    }
  }

  function validate_Gateway_WETHAddressUnchanged() private onPostCheck("validate_Gateway_WETHAddressUnchanged") onlyOnRoninNetworkOrLocal {
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 snapshotId = vm.snapshot();

    assertEq(address(ethWETH), address(IMainchainGatewayV3(ethGW).wrappedNativeToken()), "WETH address should not change");

    vm.revertTo(snapshotId);
    switchBack(prevNetwork, prevForkId);
  }

  function validate_HasBridgeManager() private onPostCheck("validate_HasBridgeManager") onlyOnRoninNetworkOrLocal {
    // assertEq(ronBM.getProxyAdmin(), ronBM, "Invalid ProxyAdmin in RoninBridgeManager, expected self");
    assertEq(IHasContracts(ronGW).getContract(ContractType.BRIDGE_MANAGER), ronBM, "Invalid RoninBridgeManager in ronGW");
    assertEq(IHasContracts(brTk).getContract(ContractType.BRIDGE_MANAGER), ronBM, "Invalid RoninBridgeManager in bridgeTracking");
    assertEq(IHasContracts(brRw).getContract(ContractType.BRIDGE_MANAGER), ronBM, "Invalid RoninBridgeManager in bridgeReward");
    assertEq(IHasContracts(brSl).getContract(ContractType.BRIDGE_MANAGER), ronBM, "Invalid RoninBridgeManager in bridgeSlash");

    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(companionNetwork);
    uint256 snapshotId = vm.snapshot();

    // assertEq(ethBM.getProxyAdmin(), ethBM, "Invalid ProxyAdmin in MainchainBridgeManager, expected self");
    assertEq(IHasContracts(ethGW).getContract(ContractType.BRIDGE_MANAGER), ethBM, "Invalid MainchainBridgeManager in ethGW");

    vm.revertTo(snapshotId);
    switchBack(prevNetwork, prevForkId);
  }

  function _calcMinSigOrVoteRequired(address bm, address gw) private view returns (uint256 minVoteOrSig) {
    uint256 minVW = IQuorum(gw).minimumVoteWeight();
    uint256 defaultVW = IBridgeManager(bm).getTotalWeight() / IBridgeManager(bm).totalBridgeOperator();
    minVoteOrSig = (minVW / defaultVW) + 1;
  }

  function _bulkSignReceipt(address[] memory signers, bytes32 receiptDigest) private pure returns (Signature[] memory sigs) {
    LibArray.inplaceAscSort(signers);

    sigs = new Signature[](signers.length);

    for (uint256 i; i < signers.length; ++i) {
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(signers[i], receiptDigest);
      sigs[i] = Signature(v, r, s);
    }
  }

  function _concat(Signature[] memory a, Signature[] memory b) private pure returns (Signature[] memory c) {
    c = new Signature[](a.length + b.length);

    for (uint256 i; i < a.length; ++i) {
      c[i] = a[i];
    }

    for (uint256 i; i < b.length; ++i) {
      c[a.length + i] = b[i];
    }
  }

  function _getReceiptHash(address emitter, bytes32 eventTopic) private returns (LibTransfer.Receipt memory receipt, bytes32 receiptHash) {
    Vm.Log[] memory recordedLogs = vm.getRecordedLogs();

    for (uint256 i; i < recordedLogs.length; ++i) {
      if (recordedLogs[i].emitter == emitter && recordedLogs[i].topics[0] == eventTopic) {
        (receiptHash, receipt) = abi.decode(recordedLogs[i].data, (bytes32, LibTransfer.Receipt));
      }
    }
  }
}
