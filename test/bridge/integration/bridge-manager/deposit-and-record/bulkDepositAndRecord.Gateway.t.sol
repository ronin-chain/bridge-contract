// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import "../../BaseIntegration.t.sol";

contract BulkDepositAndRecord_Gateway_Test is BaseIntegration_Test {
  using Transfer for Transfer.Receipt;

  address _newBridgeOperator;
  uint256 _numOperatorsForVoteExecuted;
  Transfer.Receipt _sampleReceipt;
  Transfer.Receipt[] _bulkReceipts;
  uint256 _id = 0;

  function setUp() public virtual override {
    super.setUp();

    vm.deal(address(_bridgeReward), 10 ether);
    _sampleReceipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: Token.Owner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    _numOperatorsForVoteExecuted =
      _param.roninBridgeManager.bridgeOperators.length * _param.roninBridgeManager.num / _param.roninBridgeManager.denom;
  }

  function test_bulkDepositFor_wrapUp_checkRewardAndSlash() public {
    _depositFor();
    _moveToEndPeriodAndWrapUpEpoch();

    console.log("=============== First 50 Receipts ===========");
    _bulkDepositFor();

    _wrapUpEpoch();
    _wrapUpEpoch();

    _moveToEndPeriodAndWrapUpEpoch();

    console.log("=============== Check slash and reward behavior  ===========");
    console.log("==== Check total ballot before new deposit  ====");

    logBridgeTracking();

    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), _id);
    }

    for (uint256 i = _numOperatorsForVoteExecuted; i < _param.roninBridgeManager.bridgeOperators.length; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), 0);
    }

    console.log("==== Check total ballot after new deposit  ====");
    _depositFor();

    logBridgeTracking();
    logBridgeSlash();

    lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    for (uint256 i; i < _param.roninBridgeManager.bridgeOperators.length; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      assertEq(_bridgeTracking.totalBallotOf(lastSyncedPeriod, operator), 0);
    }

    uint256[] memory toPeriodSlashArr = _bridgeSlash.getSlashUntilPeriodOf(_param.roninBridgeManager.bridgeOperators);
    for (uint256 i = _numOperatorsForVoteExecuted; i < _param.roninBridgeManager.bridgeOperators.length; i++) {
      assertEq(toPeriodSlashArr[i], 7);
    }
  }

  function _depositFor() internal {
    console.log(">> depositFor ....");
    _sampleReceipt.id = ++_id;
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.depositFor(_sampleReceipt);
    }
  }

  function _bulkDepositFor() internal {
    console.log(">> bulkDepositFor ....");
    _prepareBulkRequest();
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.tryBulkDepositFor(_bulkReceipts);
    }
  }

  function _prepareBulkRequest() internal {
    delete _bulkReceipts;

    for (uint256 i; i < 50; i++) {
      _sampleReceipt.id = ++_id;
      _bulkReceipts.push(_sampleReceipt);
    }
  }
}
