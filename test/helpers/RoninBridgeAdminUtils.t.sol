// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import "./ProposalUtils.t.sol";

contract RoninBridgeAdminUtils is ProposalUtils {
  RoninBridgeManager _contract;
  address _sender;

  constructor(uint256[] memory signerPKs, RoninBridgeManager contract_, address sender) ProposalUtils(signerPKs) {
    _contract = contract_;
    _sender = sender;
  }

  function defaultExpiryTimestamp() public view returns (uint256) {
    return block.timestamp + 10;
  }

  function functionDelegateCall(address to, bytes memory data) public {
    Proposal.ProposalDetail memory proposal = this.createProposal({
      expiryTimestamp: this.defaultExpiryTimestamp(),
      target: to,
      value: 0,
      calldata_: abi.encodeWithSignature("functionDelegateCall(bytes)", data),
      gasAmount: 2_000_000,
      nonce: _contract.round(block.chainid) + 1
    });

    SignatureConsumer.Signature[] memory signatures = this.generateSignatures(proposal);
    uint256 length = signatures.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    vm.prank(_sender);
    _contract.proposeProposalStructAndCastVotes(proposal, supports_, signatures);
  }

  function functionDelegateCallGlobal(GlobalProposal.TargetOption target, bytes memory data) public {
    GlobalProposal.GlobalProposalDetail memory proposal = this.createGlobalProposal({
      expiryTimestamp: this.defaultExpiryTimestamp(),
      targetOption: target,
      value: 0,
      calldata_: abi.encodeWithSignature("functionDelegateCall(bytes)", data),
      gasAmount: 2_000_000,
      nonce: _contract.round(0) + 1
    });

    SignatureConsumer.Signature[] memory signatures = this.generateSignaturesGlobal(proposal);
    uint256 length = signatures.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    vm.prank(_sender);
    _contract.proposeGlobalProposalStructAndCastVotes(proposal, supports_, signatures);
  }

  function functionDelegateCallsGlobal(GlobalProposal.TargetOption[] memory targetOptions, bytes[] memory datas) public {
    uint256 length = targetOptions.length;
    if (length != datas.length || length == 0) revert("Invalid length");

    bytes[] memory calldatas = new bytes[](length);
    uint256[] memory values = new uint256[](length);
    uint256[] memory gasAmounts = new uint256[](length);
    for (uint256 i; i < length; i++) {
      calldatas[i] = abi.encodeWithSignature("functionDelegateCall(bytes)", datas[i]);
      values[i] = 0;
      gasAmounts[i] = 2_000_000;
    }

    GlobalProposal.GlobalProposalDetail memory proposal = GlobalProposal.GlobalProposalDetail({
      nonce: _contract.round(0) + 1,
      expiryTimestamp: this.defaultExpiryTimestamp(),
      targetOptions: targetOptions,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });

    SignatureConsumer.Signature[] memory signatures = this.generateSignaturesGlobal(proposal);
    length = signatures.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    vm.prank(_sender);
    _contract.proposeGlobalProposalStructAndCastVotes(proposal, supports_, signatures);
  }

  function upgradeGlobal(GlobalProposal.TargetOption targetOption, uint256 nonce, bytes memory data) public {
    GlobalProposal.GlobalProposalDetail memory proposal = this.createGlobalProposal({
      expiryTimestamp: this.defaultExpiryTimestamp(),
      targetOption: targetOption,
      value: 0,
      calldata_: abi.encodeWithSignature("upgradeTo(bytes)", data),
      gasAmount: 2_000_000,
      nonce: nonce
    });

    SignatureConsumer.Signature[] memory signatures = this.generateSignaturesGlobal(proposal);
    uint256 length = signatures.length;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](length);
    for (uint256 i; i < length; i++) {
      supports_[i] = Ballot.VoteType.For;
    }
    vm.prank(_sender);
    _contract.proposeGlobalProposalStructAndCastVotes(proposal, supports_, signatures);
  }
}
