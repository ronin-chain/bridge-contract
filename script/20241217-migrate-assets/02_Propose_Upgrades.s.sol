// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { Ballot } from "src/libraries/Ballot.sol";

import { Vm } from "forge-std/Vm.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";

import { Migrate_Assets_Base } from "script/20241217-migrate-assets/Migrate_Assets_Base.s.sol";

import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";

import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration_02_Propose_Upgrades is Migrate_Assets_Base {
  using LibCompanionNetwork for *;
  using LibProxy for *;

  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 14 days;

  uint256 internal _companionChainId;
  TNetwork internal _companionNetwork;
  Proposal.ProposalDetail internal _ronProposal;
  Proposal.ProposalDetail internal _ethProposal;
  uint256 internal _expiry;

  address[] internal mockGvs;
  address[] internal mockOps;

  IRoninBridgeManager internal _ronBM;
  IMainchainBridgeManager internal _ethBM;

  function run() public virtual override {
    super.run();

    (_companionChainId, _companionNetwork) = network().companionNetworkData();

    _expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;
    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    _ethBM = IMainchainBridgeManager(vme.getAddress(_companionNetwork, Contract.MainchainBridgeManager.key()));

    _propose_upgradeAndRestrictERC20_RoninGatewayV3();
    _propose_upgradeAndRestrictERC20_MainchainGatewayV3();
  }

  function _propose_upgradeAndRestrictERC20_MainchainGatewayV3() internal {
    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    MigrateConfig memory cfg = ethConfig();
    (address[] memory tokens, address[] memory recipients, uint64[] memory remoteChainSelectors) = toWhitelistData(cfg.whitelistInfos);

    targets[0] = vme.getAddress(_companionNetwork, Contract.MainchainGatewayV3.key());
    callDatas[0] = abi.encodeCall(
      ITransparentUpgradeableProxyV2.upgradeToAndCall,
      (
        cfg.newGatewayLogic,
        abi.encodeWithSignature(
          "initializeV5(address,address,address[],address[],uint64[])", cfg.migrator, cfg.newPauseEnforcer, tokens, recipients, remoteChainSelectors
        )
      )
    );
    values[0] = 0;
    gasAmounts[0] = 1_000_000;

    LibProposal.verifyMainchainProposalGasAmount(_companionNetwork, address(_ethBM), targets, values, callDatas, gasAmounts);

    vm.broadcast(cfg.proposer);
    vm.recordLogs();
    _ronBM.propose(_companionChainId, _expiry, cfg.executor, targets, values, callDatas, gasAmounts);
    Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
    for (uint256 i; i < recordedLogs.length; ++i) {
      if (recordedLogs[i].emitter == address(_ronBM) && recordedLogs[i].topics[0] == IRoninBridgeManager.ProposalCreated.selector) {
        (_ethProposal,) = abi.decode(recordedLogs[i].data, (Proposal.ProposalDetail, address));
        break;
      }
    }
  }

  function _propose_upgradeAndRestrictERC20_RoninGatewayV3() internal {
    address gw = loadContract(Contract.RoninGatewayV3.key());

    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    MigrateConfig memory cfg = ronConfig();
    (address[] memory tokens, address[] memory recipients, uint64[] memory remoteChainSelectors) = toWhitelistData(cfg.whitelistInfos);

    targets[0] = gw;
    callDatas[0] = abi.encodeCall(
      ITransparentUpgradeableProxyV2.upgradeToAndCall,
      (
        cfg.newGatewayLogic,
        abi.encodeWithSignature(
          "initializeV4(address,address,address[],address[],uint64[])", cfg.migrator, cfg.newPauseEnforcer, tokens, recipients, remoteChainSelectors
        )
      )
    );
    values[0] = 0;
    gasAmounts[0] = 1_000_000;

    uint256 nonce = _ronBM.round(block.chainid) + 1;
    _ronProposal = LibProposal.createProposal(address(_ronBM), nonce, _expiry, targets, values, callDatas, gasAmounts);
    _ronProposal.executor = cfg.executor;

    vm.broadcast(cfg.proposer);
    _ronBM.propose(block.chainid, _expiry, cfg.executor, targets, values, callDatas, gasAmounts);
  }

  function postCheck() external {
    _postCheck();
  }

  function _postCheck() internal virtual override {
    // Simulate voting for the Ronin proposal
    LibProposal.voteFor(_ronBM, _ronProposal);
    if (_ronProposal.executor != address(0)) {
      vm.prank(_ronProposal.executor);
      _ronBM.execute(_ronProposal);
    }

    // Simulate voting for the Ethereum proposal
    genMockBOs(address(_ronBM));
    overrideMockBOs(address(_ronBM));

    Signature[] memory sigs = LibProposal.voteForBySignature(_ronBM, _ethProposal, Ballot.VoteType.For);

    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(_companionNetwork);

    overrideMockBOs(address(_ethBM));

    MigrateConfig memory cfg = ethConfig();

    // Cheat re-add executor as bridge operator since we assigned executor as bridge operator in the proposal
    address[] memory ops = new address[](1);
    ops[0] = makeAddr("cheat-re-added-sm-bo");
    uint96[] memory vws = new uint96[](1);
    vws[0] = 1;
    address[] memory gvs = new address[](1);
    gvs[0] = cfg.executor;

    address pa = LibProxy.getProxyAdmin(address(_ethBM));
    vm.prank(pa);
    ITransparentUpgradeableProxyV2(address(_ethBM)).functionDelegateCall(abi.encodeCall(IBridgeManager.addBridgeOperators, (vws, gvs, ops)));
    vm.prank(cfg.executor);
    _ethBM.relayProposal(_ethProposal, new Ballot.VoteType[](sigs.length), sigs);

    switchBack(prvNetwork, prvForkId);
  }

  function genMockBOs(
    address bm
  ) internal {
    uint256 boCount = IBridgeManager(bm).totalBridgeOperator();

    delete mockGvs;
    delete mockOps;

    for (uint256 i; i < boCount; ++i) {
      (address gv, uint256 gvPK) = makeAddrAndKey(string.concat("mock-gv-", vm.toString(vm.unixTime()), "-", vm.toString(i)));
      (address op, uint256 opPK) = makeAddrAndKey(string.concat("mock-op-", vm.toString(vm.unixTime()), "-", vm.toString(i)));

      vm.rememberKey(gvPK);
      vm.rememberKey(opPK);

      mockGvs.push(gv);
      mockOps.push(op);
    }
  }

  function overrideMockBOs(
    address bm
  ) internal {
    uint256 boCount = IBridgeManager(bm).totalBridgeOperator();
    address[] memory bos = IBridgeManager(bm).getBridgeOperators();
    address pa = bm.getProxyAdmin();
    uint96[] memory vws = new uint96[](boCount);

    for (uint256 i; i < boCount; ++i) {
      vws[i] = IBridgeManager(bm).getBridgeOperatorWeight(bos[i]);
      require(vws[i] > 0, "BridgeOperator weight should be greater than 0");
    }

    vm.prank(pa);
    ITransparentUpgradeableProxyV2(bm).functionDelegateCall(abi.encodeCall(IBridgeManager.addBridgeOperators, (vws, mockGvs, mockOps)));

    // remove real bridge operators
    vm.prank(pa);
    ITransparentUpgradeableProxyV2(bm).functionDelegateCall(abi.encodeCall(IBridgeManager.removeBridgeOperators, (bos)));
  }
}
