// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import "../../BaseIntegration.t.sol";

contract SubmitWithdrawal_MainchainGatewayV3_Test is BaseIntegration_Test {
  using Transfer for Transfer.Receipt;

  Transfer.Receipt _withdrawalReceipt;
  bytes32 _domainSeparator;

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
  }

  function test_submitWithdrawal() public {
    _withdrawalReceipt.info.quantity = 10;

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);
  }

  function _generateSignaturesFor(Transfer.Receipt memory receipt, uint256[] memory signerPKs)
    internal
    view
    returns (SignatureConsumer.Signature[] memory sigs)
  {
    sigs = new SignatureConsumer.Signature[](signerPKs.length);

    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, receipt.hash()));

      sigs[i] = _sign(signerPKs[i], digest);
    }
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (SignatureConsumer.Signature memory sig) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig.v = v;
    sig.r = r;
    sig.s = s;
  }
}
