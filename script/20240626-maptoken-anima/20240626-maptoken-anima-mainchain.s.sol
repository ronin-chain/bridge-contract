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

  function setUp() public virtual override {
    _mainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    _mainchainBridgeManager = 0x603075B625cc2cf69FbB3546C6acC2451FE792AF;

    _governorPKs = new uint256[](4);
    _governorPKs[3] = 0x0;
    _governorPKs[2] = 0x0;
    _governorPKs[0] = 0x0;
    _governorPKs[1] = 0x0;

    _governors = new address[](4);
    _governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    _governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    _governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;
  }

  function _initCaller() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function run() public override {
    console2.log("nonce", vm.getNonce(SM_GOVERNOR)); // Log nonce for workaround of nonce increase when switch network
    // _cheatStorage(_governors);
    _relayProposal();
  }
}
