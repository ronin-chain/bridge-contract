// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ICCIPLiquidityContainer {
  function provideLiquidity(uint64 remoteChainSelector, uint256 amount) external;

  function provideLiquidity(
    uint256 amount
  ) external;

  function provideSiloedLiquidity(uint64 remoteChainSelector, uint256 amount) external;
}
