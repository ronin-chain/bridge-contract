// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import "../../BaseIntegration.t.sol";

contract VoteBridgeOperator_RoninBridgeManager_Test is BaseIntegration_Test {
  event ProposalVoted(bytes32 indexed proposalHash, address indexed voter, Ballot.VoteType support, uint256 weight);

  error ErrInvalidProposalNonce(bytes4 sig);

  using LibSort for address[];

  uint256 _proposalExpiryDuration;
  uint256 _addingOperatorNum;
  address[] _addingOperators;
  address[] _addingGovernors;
  uint96[] _voteWeights;

  address[] _beforeRelayedOperators;
  address[] _beforeRelayedGovernors;

  address[] _afterRelayedOperators;
  address[] _afterRelayedGovernors;

  Ballot.VoteType[] _supports;

  GlobalProposal.GlobalProposalDetail _globalProposal;
  SignatureConsumer.Signature[] _signatures;

  bytes32 _anyValue;

  function setUp() public virtual override {
    super.setUp();

    _proposalExpiryDuration = 60;
    _addingOperatorNum = 3;

    _beforeRelayedOperators = _param.roninBridgeManager.bridgeOperators;
    _beforeRelayedGovernors = _param.roninBridgeManager.governors;

    _supports = new Ballot.VoteType[](_beforeRelayedOperators.length);
    for (uint256 i; i < _beforeRelayedGovernors.length; i++) {
      _supports[i] = Ballot.VoteType.For;
    }

    _generateAddingOperators(_addingOperatorNum);
  }

  // Should be able to vote bridge operators
  function test_voteAddBridgeOperatorsProposal() public {
    _globalProposal = _roninProposalUtils.createGlobalProposal({
      expiryTimestamp: block.timestamp + _proposalExpiryDuration,
      targetOption: GlobalProposal.TargetOption.BridgeManager,
      value: 0,
      calldata_: abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)),
      gasAmount: 1_000_000,
      nonce: _roninBridgeManager.round(0) + 1
    });

    SignatureConsumer.Signature[] memory signatures =
      _roninProposalUtils.generateSignaturesGlobal(_globalProposal, _param.test.governorPKs);

    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.expectEmit(false, true, true, true);
    emit ProposalVoted(_anyValue, _param.roninBridgeManager.governors[0], Ballot.VoteType.For, 100);

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(_globalProposal, _supports, _signatures);

    assertEq(
      _roninBridgeManager.globalProposalVoted(_globalProposal.nonce, _param.roninBridgeManager.governors[0]), true
    );
    assertEq(_roninBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should be able relay the vote of bridge operators
  function test_relayAddBridgeOperator() public {
    test_voteAddBridgeOperatorsProposal();

    // before relay
    assertEq(_mainchainBridgeManager.globalProposalRelayed(_globalProposal.nonce), false);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _beforeRelayedOperators);

    vm.prank(_param.mainchainBridgeManager.governors[0]);
    _mainchainBridgeManager.relayGlobalProposal(_globalProposal, _supports, _signatures);

    // after relay
    assertEq(_mainchainBridgeManager.globalProposalRelayed(_globalProposal.nonce), true);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should not able to relay again
  function test_RevertWhen_RelayAgain() public {
    test_relayAddBridgeOperator();

    vm.expectRevert(
      abi.encodeWithSelector(ErrInvalidProposalNonce.selector, MainchainBridgeManager.relayGlobalProposal.selector)
    );

    vm.prank(_param.mainchainBridgeManager.governors[0]);
    _mainchainBridgeManager.relayGlobalProposal(_globalProposal, _supports, _signatures);
  }

  // Should be able to vote for a larger number of bridge operators
  function test_voteForLargeNumberOfOperators(uint256 seed) public {
    uint256 numAddingOperators = seed % 10 + 10;
    _generateAddingOperators(numAddingOperators);

    _globalProposal = _roninProposalUtils.createGlobalProposal({
      expiryTimestamp: block.timestamp + _proposalExpiryDuration,
      targetOption: GlobalProposal.TargetOption.BridgeManager,
      value: 0,
      calldata_: abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingGovernors, _addingOperators)),
      gasAmount: 200_000 * numAddingOperators,
      nonce: _roninBridgeManager.round(0) + 1
    });

    SignatureConsumer.Signature[] memory signatures =
      _roninProposalUtils.generateSignaturesGlobal(_globalProposal, _param.test.governorPKs);

    for (uint256 i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }

    vm.expectEmit(false, true, true, true);
    emit ProposalVoted(_anyValue, _param.roninBridgeManager.governors[0], Ballot.VoteType.For, 100);

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(_globalProposal, _supports, _signatures);

    assertEq(
      _roninBridgeManager.globalProposalVoted(_globalProposal.nonce, _param.roninBridgeManager.governors[0]), true
    );
    assertEq(_roninBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  // Should the approved proposal can be relayed on mainchain (even when the time of expiry is passed)
  function test_relayExpiredProposal() public {
    test_voteAddBridgeOperatorsProposal();

    vm.warp(block.timestamp + _proposalExpiryDuration + 1);

    // before relay
    assertEq(_mainchainBridgeManager.globalProposalRelayed(_globalProposal.nonce), false);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _beforeRelayedOperators);

    vm.prank(_param.mainchainBridgeManager.governors[0]);
    _mainchainBridgeManager.relayGlobalProposal(_globalProposal, _supports, _signatures);

    // after relay
    assertEq(_mainchainBridgeManager.globalProposalRelayed(_globalProposal.nonce), true);
    assertEq(_mainchainBridgeManager.getBridgeOperators(), _afterRelayedOperators);
  }

  function _generateAddingOperators(uint256 num) internal {
    delete _addingOperators;
    delete _addingGovernors;
    delete _voteWeights;

    _afterRelayedOperators = _beforeRelayedOperators;
    _afterRelayedGovernors = _beforeRelayedGovernors;

    for (uint256 i; i < num; i++) {
      _addingOperators.push(makeAddr(string.concat("adding-operator", vm.toString(i))));
      _addingGovernors.push(makeAddr(string.concat("adding-governor", vm.toString(i))));
      _voteWeights.push(uint96(uint256(100)));

      _afterRelayedOperators.push(_addingOperators[i]);
      _afterRelayedGovernors.push(_addingGovernors[i]);
    }
  }
}
