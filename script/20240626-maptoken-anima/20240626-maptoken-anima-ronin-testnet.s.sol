// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import "../factories/factory-maptoken-roninchain.s.sol";
import "./base-maptoken.s.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

contract Migration__20242606_MapTokenAnimaRoninTestnet is Base__MapToken, Factory__MapTokensRoninchain {
  function _initCaller() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function run() public override {
    _governors = new address[](4);
    _governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    _governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    _governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    Proposal.ProposalDetail memory proposal = _createAndVerifyProposal();

    _proposeAndExecute(proposal);
  }
}
