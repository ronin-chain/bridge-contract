// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Transfer as LibTransfer } from "@ronin/contracts/libraries/Transfer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import "../BaseIntegration.t.sol";

interface IERC721 {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
}

interface IERC20 {
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract SubmitWithdrawal_MainchainGatewayV3_Test is BaseIntegration_Test {
  event Withdrew(bytes32 receiptHash, LibTransfer.Receipt receipt);

  error ErrInvalidOrder(bytes4);
  error ErrQueryForApprovedWithdrawal();
  error ErrReachedDailyWithdrawalLimit();
  error ErrQueryForProcessedWithdrawal();
  error ErrQueryForInsufficientVoteWeight();

  using LibTransfer for LibTransfer.Receipt;

  LibTransfer.Receipt _withdrawalReceipt;
  bytes32 _domainSeparator;

  function setUp() public virtual override {
    super.setUp();

    _domainSeparator = _mainchainGatewayV3.DOMAIN_SEPARATOR();

    _withdrawalReceipt.id = 0;
    _withdrawalReceipt.kind = LibTransfer.Kind.Withdrawal;
    _withdrawalReceipt.ronin.addr = makeAddr("requester");
    _withdrawalReceipt.ronin.tokenAddr = address(_roninWeth);
    _withdrawalReceipt.ronin.chainId = block.chainid;
    _withdrawalReceipt.mainchain.addr = makeAddr("recipient");
    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainWeth);
    _withdrawalReceipt.mainchain.chainId = block.chainid;
    _withdrawalReceipt.info.erc = Token.Standard.ERC20;
    _withdrawalReceipt.info.id = 0;
    _withdrawalReceipt.info.quantity = 10;

    vm.deal(address(_mainchainGatewayV3), 10 ether);
  }

  // test withdrawal > should not be able to withdraw without enough signature
  function test_RevertWhen_NotEnoughSignatures() public {
    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, wrapUint(_param.test.operatorPKs[0]));

    vm.expectRevert(ErrQueryForInsufficientVoteWeight.selector);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);
  }

  // test withdrawal > should not be able to withdraw eth with wrong order of signatures
  function test_RevertWhen_InvalidOrderSignatures() public {
    require(_param.test.operatorPKs.length > 1, "Amounts of operators too small");

    // swap order of signatures (operator 0 <-> operator 1)
    uint256 tempPK = _param.test.operatorPKs[0];
    _param.test.operatorPKs[0] = _param.test.operatorPKs[1];
    _param.test.operatorPKs[1] = tempPK;

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectRevert(abi.encodeWithSelector(ErrInvalidOrder.selector, IMainchainGatewayV3.submitWithdrawal.selector));

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);
  }

  // test withdrawal > should be able to withdraw eth
  function test_WithdrawNative_OnMainchain() public {
    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    uint256 balanceBefore = _withdrawalReceipt.mainchain.addr.balance;

    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    uint256 balanceAfter = _withdrawalReceipt.mainchain.addr.balance;
    assertEq(balanceAfter, balanceBefore + _withdrawalReceipt.info.quantity);
  }

  // test withdrawal > should not able to withdraw with same withdrawalId
  function test_RevertWhen_WithdrawWithSameId() public {
    test_WithdrawNative_OnMainchain();

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectRevert(ErrQueryForProcessedWithdrawal.selector);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);
  }

  // test withdrawal > should be able to withdraw for self
  function test_WithdrawForSelf() public {
    address sender = makeAddr("sender");
    _withdrawalReceipt.mainchain.addr = sender;

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    vm.prank(sender);
    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    assertEq(sender.balance, _withdrawalReceipt.info.quantity);
  }

  // test withdrawal > should be able to withdraw locked erc20
  function test_WithdrawLockedERC20() public {
    address recipient = _withdrawalReceipt.mainchain.addr;
    uint256 quantity = _withdrawalReceipt.info.quantity;

    _mainchainAxs.mint(address(_mainchainGatewayV3), quantity);

    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainAxs);
    _withdrawalReceipt.ronin.tokenAddr = address(_roninAxs);

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectEmit(address(_mainchainAxs));
    emit IERC20.Transfer(address(_mainchainGatewayV3), recipient, quantity);
    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    uint256 balanceBefore = _mainchainAxs.balanceOf(recipient);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    uint256 balanceAfter = _mainchainAxs.balanceOf(recipient);

    assertEq(balanceAfter, balanceBefore + quantity);
  }

  // test withdraw > should be able to mint new erc20 token when withdrawing
  function test_MintTokenWhileWithdrawing() public {
    address recipient = _withdrawalReceipt.mainchain.addr;
    uint256 quantity = _withdrawalReceipt.info.quantity;

    uint256 balanceBefore = _mainchainSlp.balanceOf(recipient);
    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainSlp);
    _withdrawalReceipt.ronin.tokenAddr = address(_roninSlp);

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectEmit(address(_mainchainSlp));
    emit IERC20.Transfer(address(0), address(_mainchainGatewayV3), quantity);

    vm.expectEmit(address(_mainchainSlp));
    emit IERC20.Transfer(address(_mainchainGatewayV3), recipient, quantity);

    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    uint256 balanceAfter = _mainchainSlp.balanceOf(recipient);

    assertEq(balanceAfter, balanceBefore + quantity);
  }

  // test withdraw > should be able to withdraw locked erc721
  function test_WithdrawERC721Token() public {
    address recipient = _withdrawalReceipt.mainchain.addr;

    uint256 tokenId = 22;
    _mainchainMockERC721.mint(address(_mainchainGatewayV3), tokenId);

    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainMockERC721);
    _withdrawalReceipt.ronin.tokenAddr = address(_roninMockERC721);
    _withdrawalReceipt.info.id = tokenId;
    _withdrawalReceipt.info.erc = Token.Standard.ERC721;
    _withdrawalReceipt.info.quantity = 0;

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectEmit(address(_mainchainMockERC721));
    emit IERC721.Transfer(address(_mainchainGatewayV3), recipient, tokenId);

    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    assertEq(_mainchainMockERC721.ownerOf(tokenId), address(_mainchainGatewayV3));

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    assertEq(_mainchainMockERC721.ownerOf(tokenId), recipient);
  }

  // test withdraw > should be able to mint new erc721 when withdrawing
  function test_MintERC721TokenWhileWithdrawing() public {
    address recipient = _withdrawalReceipt.mainchain.addr;

    uint256 tokenId = 22;

    _withdrawalReceipt.mainchain.tokenAddr = address(_mainchainMockERC721);
    _withdrawalReceipt.ronin.tokenAddr = address(_roninMockERC721);
    _withdrawalReceipt.info.id = tokenId;
    _withdrawalReceipt.info.erc = Token.Standard.ERC721;
    _withdrawalReceipt.info.quantity = 0;

    SignatureConsumer.Signature[] memory signatures =
      _generateSignaturesFor(_withdrawalReceipt, _param.test.operatorPKs);

    vm.expectEmit(address(_mainchainMockERC721));
    emit IERC721.Transfer(address(0), recipient, tokenId);

    vm.expectEmit(address(_mainchainGatewayV3));
    emit Withdrew(_withdrawalReceipt.hash(), _withdrawalReceipt);

    _mainchainGatewayV3.submitWithdrawal(_withdrawalReceipt, signatures);

    assertEq(_mainchainMockERC721.ownerOf(tokenId), recipient);
  }

  function _generateSignaturesFor(LibTransfer.Receipt memory receipt, uint256[] memory signerPKs)
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
