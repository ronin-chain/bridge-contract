// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

  function setUp() public virtual override {
    super.setUp();
    _config.switchTo(Network.RoninLocal.key());

    bytes memory calldata_ =
      abi.encodeCall(IHasContracts.setContract, (ContractType.BRIDGE_TRACKING, address(_bridgeTracking)));
    _roninProposalUtils.functionDelegateCallGlobal(
      GlobalProposal.TargetOption.GatewayContract, _roninNonce++, calldata_
    );

    vm.etch(address(_roninGatewayV3), address(new MockRoninGatewayV3Extended()).code);
  }

  function test_depositVote() public {
    Transfer.Receipt memory receipt = Transfer.Receipt({
      id: 0,
      kind: Transfer.Kind.Deposit,
      ronin: Token.Owner({ addr: makeAddr("recipient"), tokenAddr: address(_roninWeth), chainId: _param.test.roninChainId }),
      mainchain: Token.Owner({
        addr: makeAddr("requester"),
        tokenAddr: address(_mainchainWeth),
        chainId: _param.test.mainchainChainId
      }),
      info: Token.Info({ erc: Token.Standard.ERC20, id: 0, quantity: 100 })
    });

    _depositReceipts.push(receipt);
    receipt.id = 1;
    _depositReceipts.push(receipt);

    for (uint256 i; i < _param.roninBridgeManager.num - 1; i++) {
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
      assertEq(totalWeight, (_param.roninBridgeManager.num - 1) * 100);
    }
  }
}
