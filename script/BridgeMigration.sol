// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { GeneralConfigExtended } from "./GeneralConfigExtended.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";

contract BridgeMigration is BaseMigration {
  using ErrorHandler for bool;

  error ErrProposalOutOfGas(bytes4 sig, uint256 expectedGas);

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfigExtended).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    return "";
  }

  function _verifyProposalGasAmount(
    RoninBridgeManager _bridgeManager,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal {
    uint256 snapshotId = vm.snapshot();

    vm.startPrank(address(_bridgeManager));
    for (uint256 i; i < targets.length; i++) {
      vm.deal(address(_bridgeManager), values[i]);
      uint256 gasUsed = gasleft();
      (bool success, bytes memory returnOrRevertData) = targets[i].call{value: values[i]}(calldatas[i]);
      gasUsed = gasUsed - gasleft();
      success.handleRevert(bytes4(calldatas[i]), returnOrRevertData);

      if (gasUsed > gasAmounts[i]) {
        revert ErrProposalOutOfGas(bytes4(calldatas[i]), gasUsed);
      }
    }
    vm.stopPrank();
    vm.revertTo(snapshotId);
  }
}
