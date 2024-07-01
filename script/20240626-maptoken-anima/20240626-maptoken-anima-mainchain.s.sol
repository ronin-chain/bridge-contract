// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../factories/factory-maptoken-mainchain.s.sol";
import "./base-maptoken.s.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";

contract Migration__20242606_MapTokenAnimaMainchain is Base__MapToken, Factory__MapTokensMainchain {
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function _initCaller() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function run() public override {
    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x603075B625cc2cf69FbB3546C6acC2451FE792AF;

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

    Proposal.ProposalDetail memory proposal = _createAndVerifyProposal();

    _cheatStorage(_governors);
    _relayProposal(proposal);
  }
}
