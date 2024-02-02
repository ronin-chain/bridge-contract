// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { IsolatedGovernance } from "@ronin/contracts/libraries/IsolatedGovernance.sol";
import { VoteStatusConsumer } from "@ronin/contracts/interfaces/consumers/VoteStatusConsumer.sol";
import { MockRoninGatewayV3Extended } from "@ronin/contracts/mocks/ronin/MockRoninGatewayV3Extended.sol";
import "../BaseIntegration.t.sol";

contract DepositVote_RoninGatewayV3_Test is BaseIntegration_Test {
  using Transfer for Transfer.Receipt;

  Transfer.Receipt[] _depositReceipts;
  uint256 _numOperatorsForVoteExecuted;

  function setUp() public virtual override {
    super.setUp();

    vm.etch(address(_roninGatewayV3), address(new MockRoninGatewayV3Extended()).code);

    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: block.chainid }),
      mainchain: Token.Owner({ addr: makeAddr("requester"), tokenAddr: address(_mainchainWeth), chainId: block.chainid }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    _depositReceipts.push(receipt);
    receipt.id = 1;
    _depositReceipts.push(receipt);

    _numOperatorsForVoteExecuted =
      _param.roninBridgeManager.bridgeOperators.length * _param.roninBridgeManager.num / _param.roninBridgeManager.denom;
  }

  // @dev Should be able to bulk deposits using bridge operator accounts
  function test_tryBulkDepositFor_NotExecuted() public {
    for (uint256 i; i < _numOperatorsForVoteExecuted - 1; i++) {
      vm.prank(_param.roninBridgeManager.bridgeOperators[i]);
      _roninGatewayV3.tryBulkDepositFor(_depositReceipts);
    }

    for (uint256 i = 0; i < _depositReceipts.length; i++) {
      (VoteStatusConsumer.VoteStatus status,,,) =
        _roninGatewayV3.depositVote(_depositReceipts[i].mainchain.chainId, _depositReceipts[i].id);

      assertEq(uint256(uint8(status)), uint256(uint8(VoteStatusConsumer.VoteStatus.Pending)));

      uint256 totalWeight = MockRoninGatewayV3Extended(payable(address(_roninGatewayV3))).getDepositVoteWeight(
        _depositReceipts[i].mainchain.chainId, i, Transfer.hash(_depositReceipts[i])
      );
      assertEq(totalWeight, (_numOperatorsForVoteExecuted - 1) * 100);
    }
  }

  // Should be able to continue to vote on the votes, the later vote is not counted but is tracked
  function test_tryBulkDepositFor_Executed() public {
    test_tryBulkDepositFor_NotExecuted();

    vm.prank(_param.roninBridgeManager.bridgeOperators[_numOperatorsForVoteExecuted - 1]);
    _roninGatewayV3.tryBulkDepositFor(_depositReceipts);

    for (uint256 i = 0; i < _depositReceipts.length; i++) {
      (VoteStatusConsumer.VoteStatus status,,,) =
        _roninGatewayV3.depositVote(_depositReceipts[i].mainchain.chainId, _depositReceipts[i].id);

      assertEq(uint256(uint8(status)), uint256(uint8(VoteStatusConsumer.VoteStatus.Executed)));

      uint256 totalWeight = MockRoninGatewayV3Extended(payable(address(_roninGatewayV3))).getDepositVoteWeight(
        _depositReceipts[i].mainchain.chainId, i, Transfer.hash(_depositReceipts[i])
      );
      assertEq(totalWeight, (_numOperatorsForVoteExecuted) * 100);
    }
  }
}
