// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import "./caller-configs.s.sol";
import "./maptoken-anima-configs.s.sol";

contract Base__MapToken is Migration__Caller_Config, Migration__MapToken_Anima_Config {
  function _initCaller() internal virtual returns (address) {
    return SM_GOVERNOR;
  }

  function _initTokenList() internal virtual returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    totalToken = 1;

    infos = new MapTokenInfo[](totalToken);
    infos[0] = _animaInfo;
  }
}
