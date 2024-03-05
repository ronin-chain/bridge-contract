// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import "../../BaseIntegration.t.sol";

contract SubmitWithdrawal_MainchainGatewayV3_Native_Benchmark_Test is BaseIntegration_Test{
  using Transfer for Transfer.Receipt;

  Transfer.Receipt _withdrawalReceipt;
  bytes32 _domainSeparator;

  SignatureConsumer.Signature[] _signatures;

  function setUp() public virtual override {
    super.setUp();

    _domainSeparator = _mainchainGatewayV3.DOMAIN_SEPARATOR();

    _withdrawalReceipt.id = 0;
    _withdrawalReceipt.kind = Transfer.Kind.Withdrawal;
    _withdrawalReceipt.ronin.addr = makeAddr("requester");
    _withdrawalReceipt.ronin.tokenAddr = address(_roninWeth);
    _withdrawalReceipt.ronin.chainId = block.chainid;
    _withdrawalReceipt.mainchain.addr = makeAddr("recipient");
    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainWeth);
    _withdrawalReceipt.mainchain.chainId = block.chainid;
    _withdrawalReceipt.info.erc = Token.Standard.ERC20;
    _withdrawalReceipt.info.id = 0;
    _withdrawalReceipt.info.quantity = 0;

    vm.deal(address(_mainchainGatewayV3), 10 ether);
    vm.prank(address(_mainchainGatewayV3));
    _mainchainWeth.deposit{ value: 10 ether }();

    _withdrawalReceipt.info.quantity = 10;
    _withdrawalReceipt.ronin.tokenAddr = address(_roninAxs);
    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainAxs);

    SignatureConsumer.Signature[] memory signatures = _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs, _domainSeparator);

    for (uint i; i < signatures.length; i++) {
      _signatures.push(signatures[i]);
    }
  }

  function test_benchmark_submitWithdrawal_ERC20() public {
    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, _signatures);
  }
}
