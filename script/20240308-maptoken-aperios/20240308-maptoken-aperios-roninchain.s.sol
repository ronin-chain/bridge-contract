// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../factories/factory-maptoken-roninchain.s.sol";
import "./base-maptoken.s.sol";

contract Migration__20240308_MapTokenAperiosRoninchain is Base__MapToken, Factory__MapTokensRoninchain {
  function _initCaller() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList()
    internal
    override(Base__MapToken, Factory__MapTokensRoninchain)
    returns (uint256 totalToken, MapTokenInfo[] memory infos)
  {
    return Base__MapToken._initTokenList();
  }

  function run() public override {
    super.run();
  }
}
