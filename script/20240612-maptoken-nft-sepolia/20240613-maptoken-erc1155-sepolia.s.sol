// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
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

import { MockUSDC } from "@ronin/contracts/mocks/token/MockUSDC.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

import "../Migration.s.sol";

contract Migration__20240613_MapERC1155SepoliaMainchain is Migration {
  address internal _mainchainPauseEnforcer;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;

  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function setUp() public override {
    super.setUp();

    _mainchainPauseEnforcer = 0x61eC0ebf966AE84C414BDA715E17CeF657e039DF;
    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x603075B625cc2cf69FbB3546C6acC2451FE792AF;
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);
    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](1);
    thresholds[1] = new uint256[](1);
    thresholds[2] = new uint256[](1);
    thresholds[3] = new uint256[](1);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    // ================ USDC ERC-20 ======================

    mainchainTokens[0] = address(0xFBb71EEE2B420ea88e663B91722b41966E1C5F17);
    roninTokens[0] = address(0xDBB04B4BdBb385EB14cb3ea3C7B1FCcA55ea9160);
    standards[0] = TokenStandard.ERC1155;
    thresholds[0][0] = 0;
    thresholds[1][0] = 0;
    thresholds[2][0] = 0;
    thresholds[3][0] = 0;

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds));

    vm.prank(_mainchainBridgeManager);
    address(_mainchainGatewayV3).call(abi.encodeWithSignature("functionDelegateCall(bytes)", innerData));

    // return;

    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _mainchainGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    uint256[] memory governorPKs = new uint256[](4);
    governorPKs[3] = 0x00;
    governorPKs[2] = 0x00;
    governorPKs[0] = 0x00;
    governorPKs[1] = 0x00;

    address[] memory governors = new address[](4);
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

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
    // 2_000_000 to assure tx.gasleft is bigger than the gas of the proposal.
    MainchainBridgeManager(_mainchainBridgeManager).relayProposal{gas: 2_000_000}(proposal, supports_, signatures);
  }
}
