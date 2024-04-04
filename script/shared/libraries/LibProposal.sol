// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";
import { IGeneralConfigExtended } from "script/interfaces/IGeneralConfigExtended.sol";
import { TNetwork, Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { CoreGovernance } from "@ronin/contracts/extensions/sequential-governance/CoreGovernance.sol";
import { LibArray } from "./LibArray.sol";
import { LibErrorHandler } from "lib/foundry-deployment-kit/lib/contract-libs/src/LibErrorHandler.sol";
import { VoteStatusConsumer } from "@ronin/contracts/interfaces/consumers/VoteStatusConsumer.sol";

library LibProposal {
  using LibArray for *;
  using ECDSA for bytes32;
  using LibErrorHandler for bool;
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  error ErrProposalOutOfGas(uint256 chainId, bytes4 msgSig, uint256 gasUsed);

  uint256 internal constant DEFAULT_PROPOSAL_GAS = 1_000_000;
  Vm private constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfigExtended private constant config = IGeneralConfigExtended(LibSharedAddress.CONFIG);

  modifier preserveState() {
    uint256 snapshotId = vm.snapshot();
    _;
    vm.revertTo(snapshotId);
  }

  function getBridgeManagerDomain() internal view returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", block.chainid)) // salt
      )
    );
  }

  function createProposal(
    uint256 nonce,
    uint256 expiryTimestamp,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal returns (Proposal.ProposalDetail memory proposal) {
    address manager = config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());
    verifyProposalGasAmount(manager, targets, values, calldatas, gasAmounts);

    proposal = Proposal.ProposalDetail({
      nonce: nonce,
      chainId: block.chainid,
      expiryTimestamp: expiryTimestamp,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
  }

  function createGlobalProposal(
    uint256 nonce,
    uint256 expiryTimestamp,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts,
    GlobalProposal.TargetOption[] memory targetOptions
  ) internal returns (GlobalProposal.GlobalProposalDetail memory proposal) {
    verifyGlobalProposalGasAmount(values, calldatas, gasAmounts, targetOptions);
    proposal = GlobalProposal.GlobalProposalDetail({
      nonce: nonce,
      expiryTimestamp: expiryTimestamp,
      targetOptions: targetOptions,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
  }

  function executeProposal(RoninBridgeManager manager, Proposal.ProposalDetail memory proposal) internal {
    Ballot.VoteType support = Ballot.VoteType.For;
    address[] memory governors = manager.getGovernors();

    bool shouldPrankOnly = config.isPostChecking();
    address governor0 = governors[0];

    if (shouldPrankOnly) {
      vm.prank(governor0);
    } else {
      vm.broadcast(governor0);
    }
    manager.proposeProposalForCurrentNetwork(proposal.expiryTimestamp, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts, support);

    uint256 totalGas = proposal.gasAmounts.sum();
    // 20% more gas for each governor
    totalGas += totalGas * 20_00 / 100_00;
    // if totalGas is less than DEFAULT_PROPOSAL_GAS, set it to 120% of DEFAULT_PROPOSAL_GAS
    if (totalGas < DEFAULT_PROPOSAL_GAS) totalGas = DEFAULT_PROPOSAL_GAS * 120_00 / 100_00;

    for (uint256 i = 1; i < governors.length; ++i) {
      (VoteStatusConsumer.VoteStatus status,,,,) = manager.vote(block.chainid, proposal.nonce);
      if (status != VoteStatusConsumer.VoteStatus.Pending) break;

      address governor = governors[i];
      if (shouldPrankOnly) {
        vm.prank(governor);
      } else {
        vm.broadcast(governor);
      }

      manager.castProposalVoteForCurrentNetwork{ gas: totalGas }(proposal, support);
    }
  }

  function verifyGlobalProposalGasAmount(
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts,
    GlobalProposal.TargetOption[] memory targetOptions
  ) internal {
    address manager;
    address companionManager;
    TNetwork currentNetwork = config.getCurrentNetwork();
    TNetwork companionNetwork = config.getCompanionNetwork(currentNetwork);
    address[] memory roninTargets = new address[](targetOptions.length);
    address[] memory mainchainTargets = new address[](targetOptions.length);

    if (currentNetwork == Network.EthMainnet.key() || currentNetwork == Network.Goerli.key()) {
      manager = config.getAddress(currentNetwork, Contract.MainchainBridgeManager.key());
      companionManager = config.getAddress(companionNetwork, Contract.RoninBridgeManager.key());
    } else {
      manager = config.getAddress(currentNetwork, Contract.RoninBridgeManager.key());
      companionManager = config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
    }

    for (uint256 i; i < roninTargets.length; i++) {
      roninTargets[i] = resolveRoninTarget(targetOptions[i]);
      mainchainTargets[i] = resolveMainchainTarget(targetOptions[i]);
    }

    // Verify gas amount for ronin targets
    verifyProposalGasAmount(manager, roninTargets, values, calldatas, gasAmounts);

    // Verify gas amount for mainchain targets
    config.createFork(companionNetwork);
    config.switchTo(companionNetwork);

    // Verify gas amount for mainchain targets
    verifyProposalGasAmount(companionManager, mainchainTargets, values, calldatas, gasAmounts);

    config.switchTo(currentNetwork);
  }

  function verifyProposalGasAmount(
    address governance,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal preserveState {
    for (uint256 i; i < targets.length; i++) {
      vm.deal(governance, values[i]);
      vm.prank(governance);

      uint256 gasUsed = gasleft();
      (bool success, bytes memory returnOrRevertData) = targets[i].call{ value: values[i], gas: gasAmounts[i] }(calldatas[i]);
      gasUsed = gasUsed - gasleft();

      if (success) {
        console.log("Call", i, ": gasUsed", gasUsed);
      } else {
        console.log("Call", i, unicode": reverted. ❗ GasUsed", gasUsed);
      }
      success.handleRevert(bytes4(calldatas[i]), returnOrRevertData);

      if (gasUsed > gasAmounts[i]) revert ErrProposalOutOfGas(block.chainid, bytes4(calldatas[i]), gasUsed);
    }
  }

  function generateSignatures(
    Proposal.ProposalDetail memory proposal,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) internal view returns (SignatureConsumer.Signature[] memory sigs) {
    return generateSignaturesFor(proposal.hash(), signerPKs, support);
  }

  function generateSignaturesGlobal(
    GlobalProposal.GlobalProposalDetail memory proposal,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) internal view returns (SignatureConsumer.Signature[] memory sigs) {
    return generateSignaturesFor(proposal.hash(), signerPKs, support);
  }

  function generateSignaturesFor(
    bytes32 proposalHash,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) internal view returns (SignatureConsumer.Signature[] memory sigs) {
    sigs = new SignatureConsumer.Signature[](signerPKs.length);
    bytes32 domain = getBridgeManagerDomain();
    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = domain.toTypedDataHash(Ballot.hash(proposalHash, support));
      sigs[i] = sign(signerPKs[i], digest);
    }
  }

  function resolveRoninTarget(GlobalProposal.TargetOption targetOption) internal view returns (address) {
    TNetwork network = config.getCurrentNetwork();
    if (!(network == DefaultNetwork.RoninMainnet.key() || network == DefaultNetwork.RoninTestnet.key())) {
      network = config.getCompanionNetwork(network);
    }

    if (targetOption == GlobalProposal.TargetOption.BridgeManager) {
      return config.getAddress(network, Contract.RoninBridgeManager.key());
    }
    if (targetOption == GlobalProposal.TargetOption.GatewayContract) {
      return config.getAddress(network, Contract.RoninGatewayV3.key());
    }
    if (targetOption == GlobalProposal.TargetOption.BridgeReward) {
      return config.getAddress(network, Contract.BridgeReward.key());
    }
    if (targetOption == GlobalProposal.TargetOption.BridgeSlash) {
      return config.getAddress(network, Contract.BridgeSlash.key());
    }
    if (targetOption == GlobalProposal.TargetOption.BridgeTracking) {
      return config.getAddress(network, Contract.BridgeTracking.key());
    }

    return address(0);
  }

  function resolveMainchainTarget(GlobalProposal.TargetOption targetOption) internal view returns (address) {
    TNetwork network = config.getCurrentNetwork();
    if (!(network == Network.EthMainnet.key() || network == Network.Goerli.key())) {
      network = config.getCompanionNetwork(network);
    }

    if (targetOption == GlobalProposal.TargetOption.BridgeManager) {
      return config.getAddress(network, Contract.MainchainBridgeManager.key());
    }
    if (targetOption == GlobalProposal.TargetOption.GatewayContract) {
      return config.getAddress(network, Contract.MainchainGatewayV3.key());
    }

    return address(0);
  }

  function sign(uint256 pk, bytes32 digest) private pure returns (SignatureConsumer.Signature memory sig) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig.v = v;
    sig.r = r;
    sig.s = s;
  }
}
