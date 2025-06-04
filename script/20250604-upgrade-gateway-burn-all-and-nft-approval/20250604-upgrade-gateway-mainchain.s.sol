// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TNetwork } from "script/utils/Network.sol";

import { GatewayUpgradeConfig } from "./GatewayUpgradeConfig.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";

contract Migration__20250604_UpgradeGateway_Mainchain is GatewayUpgradeConfig {
  using LibCompanionNetwork for *;
  using LibProxy for *;

  address[] internal mockGvs;
  address[] internal mockOps;

  Proposal.ProposalDetail internal _ronProposal;
  IRoninBridgeManager internal _ronBM;
  IMainchainBridgeManager internal _ethBM;

  function run() public {
    _ronBM = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    uint256 expiry = block.timestamp + _DEFAULT_EXPIRY_DURATION;

    (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts) = _getMainchainUpgradeData();

    TNetwork companionNetwork = config.getCompanionNetwork(network());
    uint256 companionChainId = LibCompanionNetwork.companionChainId();

    _ethBM = IMainchainBridgeManager(config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key()));
    LibProposal.verifyMainchainProposalGasAmount(companionNetwork, address(_ethBM), targets, values, callDatas, gasAmounts);

    vm.broadcast(_SM_GOVERNOR);
    vm.recordLogs();
    _ronBM.propose(companionChainId, expiry, _SM_EXECUTOR, targets, values, callDatas, gasAmounts);

    Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
    for (uint256 i; i < recordedLogs.length; ++i) {
      if (recordedLogs[i].emitter == address(_ronBM) && recordedLogs[i].topics[0] == IRoninBridgeManager.ProposalCreated.selector) {
        (_ronProposal,) = abi.decode(recordedLogs[i].data, (Proposal.ProposalDetail, address));
        break;
      }
    }
  }

  function _getMainchainUpgradeData()
    internal
    view
    returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas, uint256[] memory gasAmounts)
  {
    // Get companion network to get mainchain gateway address
    TNetwork companionNetwork = config.getCompanionNetwork(network());
    address gatewayProxy = config.getAddress(companionNetwork, Contract.MainchainGatewayV3.key());

    // Get NFT data for mainchain
    (address[] memory nfts, address[] memory operators, bool[] memory approveds) = _getMainchainNftData();

    // Create arrays for 1 operation
    targets = new address[](1);
    values = new uint256[](1);
    callDatas = new bytes[](1);
    gasAmounts = new uint256[](1);

    // Single operation: Upgrade to NFT approval logic and set bulk approval
    targets[0] = gatewayProxy;
    values[0] = 0;
    callDatas[0] = abi.encodeCall(
      ITransparentUpgradeableProxyV2.upgradeToAndCall,
      (_NFT_APPROVAL_LOGIC_MAINCHAIN, abi.encodeWithSignature("bulkSetApprovalForAll(address[],address[],bool[])", nfts, operators, approveds))
    );
    gasAmounts[0] = 1_000_000;
  }

  function _postCheck() internal virtual override {
    // 1. Generate mock bridge operators with known private keys
    genMockBOs(address(_ronBM));
    overrideMockBOs(address(_ronBM));

    // 2. Generate local signatures for the proposal
    SignatureConsumer.Signature[] memory sigs = LibProposal.voteForBySignature(_ronBM, _ronProposal, Ballot.VoteType.For);

    // 3. Switch to Ethereum network
    TNetwork companionNetwork = config.getCompanionNetwork(network());
    (TNetwork prvNetwork, uint256 prvForkId) = switchTo(companionNetwork);

    // 4. Override Ethereum bridge operators with same mock operators
    overrideMockBOs(address(_ethBM));

    // 5. Add executor as bridge operator if needed
    address[] memory ops = new address[](1);
    ops[0] = makeAddr("cheat-re-added-sm-bo");
    uint96[] memory vws = new uint96[](1);
    vws[0] = 1;
    address[] memory gvs = new address[](1);
    gvs[0] = _SM_EXECUTOR;

    address pa = LibProxy.getProxyAdmin(address(_ethBM));
    vm.prank(pa);
    ITransparentUpgradeableProxyV2(address(_ethBM)).functionDelegateCall(abi.encodeCall(IBridgeManager.addBridgeOperators, (vws, gvs, ops)));

    // 6. Relay proposal with local signatures
    vm.prank(_SM_EXECUTOR);
    _ethBM.relayProposal(_ronProposal, new Ballot.VoteType[](sigs.length), sigs);

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
