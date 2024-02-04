// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Test } from "forge-std/Test.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Utils } from "script/utils/Utils.sol";

contract ProposalUtils is Utils, Test {
  using ECDSA for bytes32;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;
  using Proposal for Proposal.ProposalDetail;

  uint256[] _signerPKs;
  bytes32 _domain;

  constructor(uint256[] memory signerPKs) {
    _domain = getBridgeManagerDomain();

    for (uint256 i; i < signerPKs.length; i++) {
      _signerPKs.push(signerPKs[i]);
    }
  }

  function createProposal(
    uint256 expiryTimestamp,
    address target,
    uint256 value,
    bytes memory calldata_,
    uint256 gasAmount,
    uint256 nonce
  ) public view returns (Proposal.ProposalDetail memory proposal) {
    proposal = Proposal.ProposalDetail({
      nonce: nonce,
      chainId: block.chainid,
      expiryTimestamp: expiryTimestamp,
      targets: wrapAddress(target),
      values: wrapUint(value),
      calldatas: wrapBytes(calldata_),
      gasAmounts: wrapUint(gasAmount)
    });
  }

  function createGlobalProposal(
    uint256 expiryTimestamp,
    GlobalProposal.TargetOption targetOption,
    uint256 value,
    bytes memory calldata_,
    uint256 gasAmount,
    uint256 nonce
  ) public pure returns (GlobalProposal.GlobalProposalDetail memory proposal) {
    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](1);
    targetOptions[0] = targetOption;

    proposal = GlobalProposal.GlobalProposalDetail({
      nonce: nonce,
      expiryTimestamp: expiryTimestamp,
      targetOptions: targetOptions,
      values: wrapUint(value),
      calldatas: wrapBytes(calldata_),
      gasAmounts: wrapUint(gasAmount)
    });
  }

  function generateSignatures(
    Proposal.ProposalDetail memory proposal,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) public view returns (SignatureConsumer.Signature[] memory sigs) {
    bytes32 proposalHash = proposal.hash();
    return generateSignaturesFor(proposalHash, signerPKs, support);
  }

  function generateSignatures(Proposal.ProposalDetail memory proposal, uint256[] memory signerPKs)
    public
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    return generateSignatures(proposal, signerPKs, Ballot.VoteType.For);
  }

  function generateSignatures(Proposal.ProposalDetail memory proposal)
    public
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    return generateSignatures(proposal, _signerPKs, Ballot.VoteType.For);
  }

  function generateSignaturesGlobal(
    GlobalProposal.GlobalProposalDetail memory proposal,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) public view returns (SignatureConsumer.Signature[] memory sigs) {
    bytes32 proposalHash = proposal.hash();
    return generateSignaturesFor(proposalHash, signerPKs, support);
  }

  function generateSignaturesGlobal(GlobalProposal.GlobalProposalDetail memory proposal, uint256[] memory signerPKs)
    public
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    return generateSignaturesGlobal(proposal, signerPKs, Ballot.VoteType.For);
  }

  function generateSignaturesGlobal(GlobalProposal.GlobalProposalDetail memory proposal)
    public
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    return generateSignaturesGlobal(proposal, _signerPKs, Ballot.VoteType.For);
  }

  function getBridgeManagerDomain() public view returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", block.chainid)) // salt
      )
    );
  }

  function generateSignaturesFor(bytes32 proposalHash, uint256[] memory signerPKs, Ballot.VoteType support)
    public
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    sigs = new SignatureConsumer.Signature[](signerPKs.length);

    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = _domain.toTypedDataHash(Ballot.hash(proposalHash, support));
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
