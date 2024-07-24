// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../factories/mainchain/factory-maptoken-mainchain-sepolia.s.sol";
import "./base-maptoken.s.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";

contract Migration__20240708_MapTokenWBTCSepolia is Base__MapToken, Factory__MapTokensMainchain_Sepolia {
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function _initCaller() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensMainchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function _isLocalSimulation() internal virtual returns (bool) {
    return false;
  }

  function _initGovernors() internal override(Base__MapToken, Factory__MapTokensMainchain_Sepolia) returns (address[] memory) {
    return Base__MapToken._initGovernors();
  }

  function _initGovernorPKs() internal override(Base__MapToken, Factory__MapTokensMainchain_Sepolia) returns (uint256[] memory) {
    return Base__MapToken._initGovernorPKs();
  }

  function run() public override {
    Factory__MapTokensMainchain_Sepolia.run();
  }
}
