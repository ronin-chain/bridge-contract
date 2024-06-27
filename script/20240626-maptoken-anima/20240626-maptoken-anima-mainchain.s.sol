// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../factories/factory-maptoken-mainchain.s.sol";
import "./base-maptoken.s.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";

contract Migration__20242606_MapTokenAnimaMainchain is Base__MapToken, Factory__MapTokensMainchain {
  uint256[] private _governorPKs;
  address[] private _governors;
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function setUp() public virtual override {
    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x603075B625cc2cf69FbB3546C6acC2451FE792AF;
  }

  function _initCaller() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function _cheatStorage() internal {
    // TODO: Replace with real governors, this is for local simulation only.
    _governorPKs = new uint256[](4);
    _governorPKs[3] = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    _governorPKs[2] = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    _governorPKs[0] = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    _governorPKs[1] = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    _governors = new address[](4);
    _governors[3] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    _governors[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    _governors[0] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    _governors[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    // ================ Cheat Storage ===============

    bytes32 governorsSlot = keccak256(abi.encode(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300));

    //cheat governors addresses
    for (uint256 i; i < 4; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      vm.store(_mainchainBridgeManager, governorSlotId, bytes32(uint256(uint160(_governors[i]))));
    }
    //after cheat
    for (uint256 i; i < 4; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      bytes32 afterCheatData = vm.load(_mainchainBridgeManager, bytes32(uint256(governorsSlot) + uint256(i)));

      assertEq(afterCheatData, bytes32(uint256(uint160(_governors[i]))));
    }

    //cheat governors weights
    bytes32 governorsWeightSlot = bytes32(uint256(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300) + uint256(2));
    for (uint256 i; i < 4; ++i) {
      address key = _governors[i];
      bytes32 valueSlot = keccak256(abi.encode(key, governorsWeightSlot));
      vm.store(_mainchainBridgeManager, valueSlot, bytes32(uint256(uint96(100))));
    }
    bytes32 governorsWeightData = vm.load(_mainchainBridgeManager, keccak256(abi.encode(0x087D08e3ba42e64E3948962dd1371F906D1278b9, governorsWeightSlot)));
  }

  function _verifyAndExecuteProposal() internal virtual override {
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, uint256[] memory gasAmounts) = _prepareProposal();
    _cheatStorage();

    // uint256 chainId = network().companionChainId();
    uint256 expiredTime = block.timestamp + 14 days;
    _mainchainProposalUtils = new MainchainBridgeAdminUtils(2021, _governorPKs, MainchainBridgeManager(_mainchainBridgeManager), _governors[0]);

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: MainchainBridgeManager(_mainchainBridgeManager).round(11155111) + 1,
      chainId: block.chainid,
      expiryTimestamp: expiredTime,
      executor: address(0),
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });
    console2.log("preparing...");

    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](4);
    supports_[0] = Ballot.VoteType.For;
    supports_[1] = Ballot.VoteType.For;
    supports_[2] = Ballot.VoteType.For;
    supports_[3] = Ballot.VoteType.For;

    SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignatures(proposal, _governorPKs);
    vm.broadcast(_governors[0]);
    MainchainBridgeManager(_mainchainBridgeManager).relayProposal{ gas: 2_000_000 }(proposal, supports_, signatures);
  }

  function run() public override {
    console2.log("nonce", vm.getNonce(SM_GOVERNOR)); // Log nonce for workaround of nonce increase when switch network
    super.run();
  }
}
