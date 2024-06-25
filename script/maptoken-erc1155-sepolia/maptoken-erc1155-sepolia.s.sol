// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { stdStorage, StdStorage, stdStorageSafe } from "forge-std/Test.sol";

import { MockUSDC } from "@ronin/contracts/mocks/token/MockUSDC.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "../Migration.s.sol";

contract Migration__MapERC1155Sepolia is Migration {
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  using stdStorageSafe for StdStorage;

  function setUp() public override {
    super.setUp();

    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x603075B625cc2cf69FbB3546C6acC2451FE792AF;
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    // ================ Mock ERC-1155 ======================
    mainchainTokens[0] = address(0x25A9beea337cC48fca4D8848Ef3Ae1b5F28eB0ab);
    roninTokens[0] = address(0x00e2b6f0b196b411c8e0eef355a920d4d3221ab968);
    standards[0] = TokenStandard.ERC1155;

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokens, (mainchainTokens, roninTokens, standards));

    vm.prank(_mainchainBridgeManager);
    address(_mainchainGatewayV3).call(abi.encodeWithSignature("functionDelegateCall(bytes)", innerData));

    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    uint256[] memory governorPKs = new uint256[](4);
    governorPKs[3] = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    governorPKs[2] = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    governorPKs[0] = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    governorPKs[1] = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    address[] memory governors = new address[](4);
    governors[3] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    governors[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    governors[0] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    governors[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    // ================ Cheat Storage ===============

    bytes32 governorsSlot = keccak256(abi.encode(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300));

    //cheat governors addresses
    for (uint256 i; i < 4; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      vm.store(_mainchainBridgeManager, governorSlotId, bytes32(uint256(uint160(governors[i]))));
    }
    //after cheat
    for (uint256 i; i < 4; ++i) {
      bytes32 governorSlotId = bytes32(uint256(governorsSlot) + uint256(i));
      bytes32 afterCheatData = vm.load(_mainchainBridgeManager, bytes32(uint256(governorsSlot) + uint256(i)));

      assertEq(afterCheatData, bytes32(uint256(uint160(governors[i]))));
    }

    //cheat governors weights
    bytes32 governorsWeightSlot = bytes32(uint256(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300) + uint256(2));
    for (uint256 i; i < 4; ++i) {
      address key = governors[i];
      bytes32 valueSlot = keccak256(abi.encode(key, governorsWeightSlot));
      vm.store(_mainchainBridgeManager, valueSlot, bytes32(uint256(uint96(100))));
    }
    bytes32 governorsWeightData = vm.load(_mainchainBridgeManager, keccak256(abi.encode(0x087D08e3ba42e64E3948962dd1371F906D1278b9, governorsWeightSlot)));

    _mainchainProposalUtils = new MainchainBridgeAdminUtils(2021, governorPKs, MainchainBridgeManager(_mainchainBridgeManager), governors[0]);

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

    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](4);
    supports_[0] = Ballot.VoteType.For;
    supports_[1] = Ballot.VoteType.For;
    supports_[2] = Ballot.VoteType.For;
    supports_[3] = Ballot.VoteType.For;

    SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignatures(proposal, governorPKs);
    vm.broadcast(governors[0]);
    MainchainBridgeManager(_mainchainBridgeManager).relayProposal{ gas: 2_000_000 }(proposal, supports_, signatures);
  }
}
