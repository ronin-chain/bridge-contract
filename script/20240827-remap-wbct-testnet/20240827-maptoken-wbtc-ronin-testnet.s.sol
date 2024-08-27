// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import "../factories/roninchain/factory-maptoken-ronin-testnet.s.sol";
import "./base-maptoken.s.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

contract Migration__20240827_MapTokenWBTCRoninTestnet is Base__MapToken, Factory__MapTokensRonin_Testnet {
  function _initCaller() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function _initGovernors() internal override(Base__MapToken, Factory__MapTokensRonin_Testnet) returns (address[] memory) {
    return Base__MapToken._initGovernors();
  }

  function run() public override {
    Factory__MapTokensRonin_Testnet.run();
  }
}
