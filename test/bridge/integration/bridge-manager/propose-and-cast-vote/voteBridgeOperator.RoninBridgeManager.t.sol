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
  using LibSort for address[];

  uint256 _proposalExpiryDuration;
  uint256 _addingOperatorNum;
  address[] _addingOperators;
  address[] _addingGovernors;
  uint96[] _voteWeights;

  address[] _beforeRelayedOperators;
  address[] _beforeRelayedGovernors;

  Ballot.VoteType[] _supports;

  function setUp() public virtual override {
    super.setUp();
    _config.switchTo(Network.RoninLocal.key());

    _proposalExpiryDuration = 60;
    _addingOperatorNum = 3;

    _beforeRelayedOperators = _param.roninBridgeManager.bridgeOperators;
    _beforeRelayedGovernors = _param.roninBridgeManager.governors;

    _supports = new Ballot.VoteType[](_beforeRelayedOperators.length);
    for (uint256 i; i < _beforeRelayedGovernors.length; i++) {
      _supports[i] = Ballot.VoteType.For;
    }

    for (uint256 i; i < _addingOperatorNum; i++) {
      _addingOperators.push(makeAddr(string.concat("adding-operator", vm.toString(i))));
      _addingGovernors.push(makeAddr(string.concat("adding-governor", vm.toString(i))));
      _voteWeights.push(uint96(uint256(100)));
    }
  }

  function test_voteBridgeOperators() public {
    GlobalProposal.GlobalProposalDetail memory globalProposal = _roninProposalUtils.createGlobalProposal({
      expiryTimestamp: block.timestamp + _proposalExpiryDuration,
      targetOption: GlobalProposal.TargetOption.BridgeManager,
      value: 0,
      calldata_: abi.encodeCall(IBridgeManager.addBridgeOperators, (_voteWeights, _addingOperators, _addingGovernors)),
      gasAmount: 500_000,
      nonce: _roninNonce++
    });

    SignatureConsumer.Signature[] memory signatures =
      _roninProposalUtils.generateSignaturesGlobal(globalProposal, _param.test.governorPKs);

    vm.prank(_param.roninBridgeManager.governors[0]);
    _roninBridgeManager.proposeGlobalProposalStructAndCastVotes(globalProposal, _supports, signatures);
  }
}
