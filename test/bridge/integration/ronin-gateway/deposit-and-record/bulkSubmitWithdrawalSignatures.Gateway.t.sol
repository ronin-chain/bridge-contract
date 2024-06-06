// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import "../../BaseIntegration.t.sol";

contract BulkSubmitWithdrawalSignatures_Gateway_Test is BaseIntegration_Test {
  uint256 _numOperatorsForVoteExecuted;
  uint256 _sampleReceipt;
  uint256[] _withdrawals;
  bytes[] _signatures;
  uint256 _id = 0;

  function setUp() public override {
    super.setUp();

    vm.deal(address(_bridgeReward), 10 ether);

    _numOperatorsForVoteExecuted = (_roninBridgeManager.minimumVoteWeight() - 1) / 100 + 1;
    console.log("Num operators for vote executed:", _numOperatorsForVoteExecuted);
    console.log("Total operators:", _param.roninBridgeManager.bridgeOperators.length);
  }

  function test_minimum_bulkSubmitWithdrawalSignatures() external {
    _bulkSubmitWithdrawalSignatures(_numOperatorsForVoteExecuted);

    _wrapUpEpoch();
    _wrapUpEpoch();

    _moveToEndPeriodAndWrapUpEpoch();

    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), _id, "Total ballot should be equal to the number of receipts");
    }
  }

  function test_allVoters_bulkSubmitWithdrawalSignatures() external {
    uint256 numAllOperator = _param.roninBridgeManager.bridgeOperators.length;
    _bulkSubmitWithdrawalSignatures(numAllOperator);

    _wrapUpEpoch();

    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < numAllOperator; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), _id, "Total ballot should be equal to the number of receipts");
    }
  }

  function _bulkSubmitWithdrawalSignatures(uint256 numVote) private {
    console.log(">> _bulkSubmitWithdrawalSignatures ....");
    _prepareBulkRequest();

    for (uint256 i; i < numVote; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.bulkSubmitWithdrawalSignatures(_withdrawals, _signatures);

      for (uint256 j; j < _withdrawals.length; j++) {
        address[] memory op = new address[](1);
        op[0] = _param.roninBridgeManager.bridgeOperators[i];
        bytes[] memory sig = _roninGatewayV3.getWithdrawalSignatures(_withdrawals[j], op);

        assertTrue(sig[0].length > 0, "Withdraw Receipt should be voted");
      }
    }
  }

  function _prepareBulkRequest() internal {
    delete _withdrawals;
    delete _signatures;

    for (uint256 i; i < 50; i++) {
      _sampleReceipt = ++_id;
      _withdrawals.push(_sampleReceipt);
      _signatures.push(abi.encodePacked("signature", i));
    }
  }
}
