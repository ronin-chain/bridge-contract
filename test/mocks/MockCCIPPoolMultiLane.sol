// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockCCIPPoolMultiLane {
  using SafeERC20 for IERC20;

  event LiquidityAdded(address indexed provider, uint256 indexed amount);

  IERC20 public immutable i_token;

  mapping(uint64 => uint256) public s_lockedTokensByChainSelector;

  constructor(
    address token
  ) {
    i_token = IERC20(token);
  }

  function provideLiquidity(uint64 remoteChainSelector, uint256 amount) external {
    s_lockedTokensByChainSelector[remoteChainSelector] += amount;

    i_token.safeTransferFrom(msg.sender, address(this), amount);

    emit LiquidityAdded(msg.sender, amount);
  }
}
