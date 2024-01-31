// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

import "forge-std/console2.sol";

import "./maptoken-pixel-configs.s.sol";
import "./update-axiechat-config.s.sol";


contract Migration__20240131_MapTokenPixelRoninchain is BridgeMigration, Migration__MapToken_Pixel_Config, Migration__Update_AxieChat_Config {
  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;

  address _cheatingGovernor;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());

    _cheatingGovernor = makeAddr("cheat-governor");
  }

  function _cheatWeightGovernor(address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
  }

  function run() public {
    _cheatWeightGovernor(_governor);
    _cheatWeightGovernor(_cheatingGovernor);

    uint256 expiredTime = block.timestamp + 10 days;
    GlobalProposal.TargetOption[] memory targetOptions = new GlobalProposal.TargetOption[](2);
    uint256[] memory values = new uint256[](2);
    bytes[] memory calldatas = new bytes[](2);
    uint256[] memory gasAmounts = new uint256[](2);

    targetOptions[0] = GlobalProposal.TargetOption.BridgeManager;
    values[0] = 0;
    calldatas[0] = _addAxieChatGovernorAddress();
    gasAmounts[0] = 1_000_000;

    targetOptions[1] = GlobalProposal.TargetOption.BridgeManager;
    values[1] = 0;
    calldatas[1] = _removeAxieChatGovernorAddress();
    gasAmounts[1] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    _verifyGlobalProposalGasAmount(targetOptions, values, calldatas, gasAmounts);

    vm.broadcast(_governor);

        // function proposeGlobal(
        //   uint256 expiryTimestamp,
        //   GlobalProposal.TargetOption[] calldata targetOptions,
        //   uint256[] calldata values,
        //   bytes[] calldata calldatas,
        //   uint256[] calldata gasAmounts)
    _roninBridgeManager.proposeGlobal(
      expiredTime,
      targetOptions,
      values,
      calldatas,
      gasAmounts
    );
  }


}
