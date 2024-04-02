// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import "../../BaseIntegration.t.sol";

contract BulkAcknowledgeMainchainWithdrew_Gateway_Test is BaseIntegration_Test {
  uint256 _numOperatorsForVoteExecuted;
  uint256 _sampleReceipt;
  uint256[] _bulkReceipts;
  uint256 _id = 0;

  function setUp() public override {
    super.setUp();

    vm.deal(address(_bridgeReward), 10 ether);

    _numOperatorsForVoteExecuted = (_roninBridgeManager.minimumVoteWeight() - 1) / 100 + 1;
    console.log("Num operators for vote executed:", _numOperatorsForVoteExecuted);
    console.log("Total operators:", _param.roninBridgeManager.bridgeOperators.length);
  }

  function test_minimum_bulkAcknowledgeMainchainWithdrew() external {
    _bulkAcknowledgeMainchainWithdrew(_numOperatorsForVoteExecuted);

    _wrapUpEpoch();
    _wrapUpEpoch();

    _moveToEndPeriodAndWrapUpEpoch();

    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), _id, "Total ballot should be equal to the number of receipts");
    }
  }

  function test_allVoters_AcknowledgeMainchainWithdrew() external {
    uint256 numAllOperator = _param.roninBridgeManager.bridgeOperators.length;
    _bulkAcknowledgeMainchainWithdrew(numAllOperator);

    _wrapUpEpoch();

    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < numAllOperator; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), _id, "Total ballot should be equal to the number of receipts");
    }
  }

  function _bulkAcknowledgeMainchainWithdrew(uint256 numVote) private {
    console.log(">> tryBulkAcknowledgeMainchainWithdrew ....");
    _prepareBulkRequest();
    for (uint256 i; i < numVote; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      bool[] memory _executedReceipts = _roninGatewayV3.tryBulkAcknowledgeMainchainWithdrew(_bulkReceipts);

      for (uint256 j; j < _executedReceipts.length; j++) {
        assertTrue(_roninGatewayV3.mainchainWithdrewVoted(_bulkReceipts[j], _param.roninBridgeManager.bridgeOperators[i]), "Withdraw Receipt should be voted");
      }
    }
  }

  function _prepareBulkRequest() internal {
    delete _bulkReceipts;

    for (uint256 i; i < 50; i++) {
      _sampleReceipt = ++_id;
      _bulkReceipts.push(_sampleReceipt);
    }
  }
}
