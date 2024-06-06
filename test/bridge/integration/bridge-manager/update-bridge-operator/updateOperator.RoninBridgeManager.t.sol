// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { LibTokenOwner, TokenOwner } from "@ronin/contracts/libraries/LibTokenOwner.sol";
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
      ronin: TokenOwner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: TokenOwner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: TokenInfo({ erc: TokenStandard.ERC20, id: 0, quantity: 100 })
    });
    // ids: new uint256[](0),
    // quantities: new uint256[](0)

    for (uint256 i; i < 50; i++) {
      first50Receipts.push(sampleReceipt);
      second50Receipts.push(sampleReceipt);
      first50Receipts[i].id = id;
      second50Receipts[i].id = id + 50;

      id++;
    }

    _numOperatorsForVoteExecuted = (_roninBridgeManager.minimumVoteWeight() - 1) / 100 + 1;
  }

  function test_updateOperator_and_wrapUpEpoch() public {
    vm.skip(true);
    // // Disable test due to not supporting update operator
    // vm.skip(true);
    // console.log("=============== Test Update Operator ===========");

    // _depositFor();
    // _moveToEndPeriodAndWrapUpEpoch();

    // console.log("=============== First 50 Receipts ===========");
    // // _bulkDepositFor(first50Receipts);

    // for (uint i; i < 50; i++) {
    //   _depositFor();
    // }

    // console.log("=============== Update bridge operator ===========");
    // _updateBridgeOperator();

    // console.log("=============== Second 50 Receipts ===========");
    // // _bulkDepositFor(second50Receipts);
    // for (uint i; i < 50; i++) {
    //   _depositFor();
    // }

    // _wrapUpEpoch();
    // _wrapUpEpoch();

    // _moveToEndPeriodAndWrapUpEpoch();

    // console.log("=============== Check slash and reward behavior  ===========");
    // _depositFor();

    // logBridgeTracking();
    // logBridgeSlash();
  }

  // function _updateBridgeOperator() internal {
  //   vm.prank(_param.roninBridgeManager.governors[0]);
  //   address previousOperator = _param.roninBridgeManager.bridgeOperators[0];
  //   _roninBridgeManager.updateBridgeOperator(previousOperator, _newBridgeOperator);
  //   _param.roninBridgeManager.bridgeOperators[0] = _newBridgeOperator;

  //   console.log(
  //     "Update operator: ",
  //     string(abi.encodePacked(vm.toString(previousOperator), " => ", vm.toString(_newBridgeOperator)))
  //   );
  // }

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
}
