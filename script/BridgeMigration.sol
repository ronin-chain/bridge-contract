// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { TNetwork } from "foundry-deployment-kit/types/Types.sol";


import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { ErrorHandler } from "@ronin/contracts/libraries/ErrorHandler.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";

import { GeneralConfigExtended } from "./GeneralConfigExtended.sol";
import { IGeneralConfigExtended } from "./IGeneralConfigExtended.sol";
import { Network } from "./utils/Network.sol";
import { Contract } from "./utils/Contract.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";

contract BridgeMigration is BaseMigration {
  using ErrorHandler for bool;

  error ErrProposalOutOfGas(bytes4 sig, uint256 expectedGas);

  IGeneralConfigExtended internal constant _config = IGeneralConfigExtended(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfigExtended).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    return "";
  }

  function _verifyGlobalProposalGasAmount(
    GlobalProposal.TargetOption[] memory targetOptions,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal {
    address[] memory roninTargets = new address[](targetOptions.length);
    address[] memory mainchainTargets = new address[](targetOptions.length);
    for (uint i; i < roninTargets.length; i++) {
      roninTargets[i] = _resolveRoninTarget(targetOptions[i]);
      mainchainTargets[i] = _resolveMainchainTarget(targetOptions[i]);
    }
    _verifyRoninProposalGasAmount(roninTargets, values, calldatas, gasAmounts);
    _verifyMainchainProposalGasAmount(mainchainTargets, values, calldatas, gasAmounts);
  }

  function _resolveRoninTarget(GlobalProposal.TargetOption targetOption) internal returns (address) {
    _config.switchTo(DefaultNetwork.RoninMainnet.key());
    if (targetOption == GlobalProposal.TargetOption.BridgeManager)
      return _config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());

    if (targetOption == GlobalProposal.TargetOption.GatewayContract)
      return _config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());

    if (targetOption == GlobalProposal.TargetOption.BridgeReward)
      return _config.getAddressFromCurrentNetwork(Contract.BridgeReward.key());

    if (targetOption == GlobalProposal.TargetOption.BridgeSlash)
      return _config.getAddressFromCurrentNetwork(Contract.BridgeSlash.key());

    if (targetOption == GlobalProposal.TargetOption.BridgeTracking)
      return _config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());

    return address(0);
  }

  function _resolveMainchainTarget(GlobalProposal.TargetOption targetOption) internal returns (address) {
    _config.createFork(Network.EthMainnet.key());
    _config.switchTo(Network.EthMainnet.key());
    if (targetOption == GlobalProposal.TargetOption.BridgeManager)
      return _config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());

    if (targetOption == GlobalProposal.TargetOption.GatewayContract)
      return _config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());

    return address(0);
  }

  function _verifyRoninProposalGasAmount(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal {
    _config.switchTo(DefaultNetwork.RoninMainnet.key());

    address roninBridgeManager = _config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());
    uint256 snapshotId = vm.snapshot();
    vm.startPrank(address(roninBridgeManager));
    _verifyProposalGasAmount(roninBridgeManager, targets, values, calldatas, gasAmounts);
    vm.stopPrank();
    vm.revertTo(snapshotId);
  }

  function _verifyMainchainProposalGasAmount(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) internal {
    _config.createFork(Network.EthMainnet.key());
    _config.switchTo(Network.EthMainnet.key());

    address mainchainBridgeManager = _config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());
    uint256 snapshotId = vm.snapshot();

    vm.startPrank(address(mainchainBridgeManager));
    _verifyProposalGasAmount(mainchainBridgeManager, targets, values, calldatas, gasAmounts);
    vm.stopPrank();
    vm.revertTo(snapshotId);

    _config.switchTo(DefaultNetwork.RoninMainnet.key());
  }

  function _verifyProposalGasAmount(
    address bridgeManager,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) private {
    for (uint256 i; i < targets.length; i++) {
      vm.deal(address(bridgeManager), values[i]);
      uint256 gasUsed = gasleft();
      (bool success, bytes memory returnOrRevertData) = targets[i].call{ value: values[i] }(calldatas[i]);
      gasUsed = gasUsed - gasleft();
      if (success) {
        console2.log("Call", i, ": gasUsed", gasUsed);
      } else {
        console2.log("Call", i, unicode": reverted. ❗ GasUsed", gasUsed);
      }
      success.handleRevert(bytes4(calldatas[i]), returnOrRevertData);

      if (gasUsed > gasAmounts[i]) {
        revert ErrProposalOutOfGas(bytes4(calldatas[i]), gasUsed);
      }
    }
  }
}
