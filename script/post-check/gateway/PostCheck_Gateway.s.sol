// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PostCheck_Gateway_DepositAndWithdraw } from "./deposit-withdraw/PostCheck_Gateway_DepositAndWithdraw.s.sol";

abstract contract PostCheck_Gateway is PostCheck_Gateway_DepositAndWithdraw {
  function _validate_Gateway() internal onPostCheck("_validate_Gateway") {
    _validate_Gateway_DepositAndWithdraw();
  }
}
