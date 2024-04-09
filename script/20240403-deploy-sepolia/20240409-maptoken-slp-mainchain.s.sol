// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

import "./maptoken-slp-configs.s.sol";
import "../BridgeMigration.sol";

contract Migration__20240409_MapTokenSlpMainchain is BridgeMigration, Migration__MapToken_Slp_Config {
  address internal _mainchainPauseEnforcer;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;

  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function setUp() public override {
    super.setUp();

    _mainchainPauseEnforcer = 0x61eC0ebf966AE84C414BDA715E17CeF657e039DF;
    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x5396b75c9eb8D1153D2B8a0Bb9a8c4B1541f758d;
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    Token.Standard[] memory standards = new Token.Standard[](1);
    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](1);
    thresholds[1] = new uint256[](1);
    thresholds[2] = new uint256[](1);
    thresholds[3] = new uint256[](1);

    // uint256 expiredTime = block.timestamp + 10 days;
    // address[] memory targets = new address[](1);
    // uint256[] memory values = new uint256[](1);
    // bytes[] memory calldatas = new bytes[](1);
    // uint256[] memory gasAmounts = new uint256[](1);

    // ================ SLP ERC-20 ======================

    MockSLP _mainchainSlp = new SLPDeploy().run();

    assertEq(_mainchainSlp.decimals(), 0);

    mainchainTokens[0] = address(_mainchainSlp);
    roninTokens[0] = _slpRoninToken;
    standards[0] = Token.Standard.ERC20;
    thresholds[0][0] = _highTierThreshold;
    thresholds[1][0] = _lockedThreshold;
    thresholds[2][0] = _unlockFeePercentages;
    thresholds[3][0] = _dailyWithdrawalLimit;

    bytes memory innerData = abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (
      mainchainTokens,
      roninTokens,
      standards,
      thresholds
    ));

    vm.startBroadcast(0x968D0Cd7343f711216817E617d3f92a23dC91c07);
    address(_mainchainGatewayV3).call(abi.encodeWithSignature("functionDelegateCall(bytes)",innerData));

    _mainchainSlp.mint(address(_mainchainGatewayV3), 50_000_000);
    _mainchainSlp.mint(address(0xC65C6BEA96666f150BEF9b936630f6355BfFCC06), 100_000);

    return;






    // bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    // targets[0] = _mainchainGatewayV3;
    // values[0] = 0;
    // calldatas[0] = proxyData;
    // gasAmounts[0] = 1_000_000;

    // targets[1] = _mainchainGatewayV3;
    // values[1] = 0;
    // calldatas[1] = abi.encodeWithSignature("functionDelegateCall(bytes)", abi.encodeCall(GatewayV3.setEmergencyPauser, (
    //   _mainchainPauseEnforcer
    // )));
    // gasAmounts[1] = 1_000_000;

    // // ================ VERIFY AND EXECUTE PROPOSAL ===============

    // uint256[] memory governorPKs = new uint256[](4);
    // governorPKs[3] = 0x00;
    // governorPKs[2] = 0x00;
    // governorPKs[0] = 0x00;
    // governorPKs[1] = 0x00;

    // address[] memory governors = new address[](4);
    // governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    // governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    // governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    // governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    // _mainchainProposalUtils = new MainchainBridgeAdminUtils(
    //   2021, governorPKs, MainchainBridgeManager(_mainchainBridgeManager), governors[0]
    // );

    // Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
    //   nonce: MainchainBridgeManager(_mainchainBridgeManager).round(11155111) + 1,
    //   chainId: block.chainid,
    //   expiryTimestamp: expiredTime,
    //   targets: targets,
    //   values: values,
    //   calldatas: calldatas,
    //   gasAmounts: gasAmounts
    // });

    // Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](4);
    // supports_[0] = Ballot.VoteType.For;
    // supports_[1] = Ballot.VoteType.For;
    // supports_[2] = Ballot.VoteType.For;
    // supports_[3] = Ballot.VoteType.For;

    // SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignatures(proposal, governorPKs);

    // vm.broadcast(governors[0]);
    // MainchainBridgeManager(_mainchainBridgeManager).relayProposal(proposal, supports_, signatures);
  }
}
