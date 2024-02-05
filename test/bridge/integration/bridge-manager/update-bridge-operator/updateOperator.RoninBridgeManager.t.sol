// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import "../../BaseIntegration.t.sol";

contract UpdateOperator_RoninBridgeManager_Test is BaseIntegration_Test {
  using Transfer for Transfer.Receipt;

  address _newBridgeOperator;
  uint256 _numOperatorsForVoteExecuted;
  Transfer.Receipt[] first50Receipts;
  Transfer.Receipt[] second50Receipts;
  uint256 id = 0;

  function setUp() public virtual override {
    super.setUp();

    vm.deal(address(_bridgeReward), 10 ether);
    _newBridgeOperator = makeAddr("new-bridge-operator");
    Transfer.Receipt memory sampleReceipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: Token.Owner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    for (uint256 i; i < 50; i++) {
      first50Receipts.push(sampleReceipt);
      second50Receipts.push(sampleReceipt);
      first50Receipts[i].id = id;
      second50Receipts[i].id = id + 50;

      id++;
    }

    _numOperatorsForVoteExecuted =
      _param.roninBridgeManager.bridgeOperators.length * _param.roninBridgeManager.num / _param.roninBridgeManager.denom;
  }

  function test_updateOperator_and_wrapUpEpoch() public {
    console.log("=============== Test Update Operator ===========");

    _depositFor();
    _moveToEndPeriodAndWrapUpEpoch();

    console.log("=============== First 50 Receipts ===========");
    _bulkDepositFor(first50Receipts);

    console.log("=============== Update bridge operator ===========");
    _updateBridgeOperator();

    console.log("=============== Second 50 Receipts ===========");
    _bulkDepositFor(second50Receipts);
    _wrapUpEpoch();

    _moveToEndPeriodAndWrapUpEpoch();

    console.log("=============== Check slash and reward behavior  ===========");
    _depositFor();
    logBridgeTracking();

    logBridgeSlash();
  }

  function _updateBridgeOperator() internal {
    vm.prank(_param.roninBridgeManager.governors[0]);
    address previousOperator = _param.roninBridgeManager.bridgeOperators[0];
    _roninBridgeManager.updateBridgeOperator(_newBridgeOperator);
    _param.roninBridgeManager.bridgeOperators[0] = _newBridgeOperator;

    console.log(
      "Update operator: ",
      string(abi.encodePacked(vm.toString(previousOperator), " => ", vm.toString(_newBridgeOperator)))
    );
  }

  function _depositFor() internal {
    console.log(">> depositFor ....");
    Transfer.Receipt memory sampleReceipt = first50Receipts[0];
    sampleReceipt.id = ++id + 50;
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.depositFor(sampleReceipt);
    }
  }

  function _bulkDepositFor(Transfer.Receipt[] memory receipts) internal {
    console.log(">> bulkDepositFor ....");
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      console.log(" -> Operator vote:", _param.roninBridgeManager.bridgeOperators[i]);
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.tryBulkDepositFor(receipts);
    }
  }

  function logBridgeTracking() public {
    console.log(">> logBridgeTracking ....");
    uint256 currentPeriod = _validatorSet.currentPeriod();
    uint256 lastSyncedPeriod = uint256(vm.load(address(_bridgeTracking), bytes32(uint256(11))));
    console.log(" -> current period:", currentPeriod);
    console.log("  -> total votes:", _bridgeTracking.totalVote(currentPeriod));
    console.log("  -> total ballot:", _bridgeTracking.totalBallot(currentPeriod));
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      console.log("  -> total ballot of:", operator, _bridgeTracking.totalBallotOf(currentPeriod, operator));
    }

    console.log(" -> lastSynced period:", lastSyncedPeriod);
    console.log("  -> total votes:", _bridgeTracking.totalVote(lastSyncedPeriod));
    console.log("  -> total ballot:", _bridgeTracking.totalBallot(lastSyncedPeriod));
    for (uint256 i; i < _numOperatorsForVoteExecuted; i++) {
      address operator = _param.roninBridgeManager.bridgeOperators[i];
      console.log("  -> total ballot of:", operator, _bridgeTracking.totalBallotOf(lastSyncedPeriod, operator));
    }
  }

  function logBridgeSlash() public {
    console.log(">> logBridgeSlash ....");

    uint256[] memory periods = _bridgeSlash.getSlashUntilPeriodOf(_param.roninBridgeManager.bridgeOperators);
    for (uint256 i; i < _param.roninBridgeManager.bridgeOperators.length; i++) {
      console.log(" -> slash operator until:", _param.roninBridgeManager.bridgeOperators[i], periods[i]);
    }
  }
}
