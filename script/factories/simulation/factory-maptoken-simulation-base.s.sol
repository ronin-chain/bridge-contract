// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Migration } from "../../Migration.s.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

abstract contract Factory__MapTokensSimulation_Base is Migration {
  modifier inSimulation() {
    uint256 snapshot = vm.snapshot();
    _;
    vm.revertTo(snapshot);
  }

  function simulate() public virtual {
    _setUp();
  }

  function _setUp() internal virtual;

  function _cheatWeightOperator(IBridgeManager manager, address gov) internal virtual {
    bytes32 governorsWeightSlot = bytes32(uint256(0xc648703095712c0419b6431ae642c061f0a105ac2d7c3d9604061ef4ebc38300) + uint256(2));

    bytes32 $ = keccak256(abi.encode(gov, governorsWeightSlot));
    bytes32 opAndWeight = vm.load(address(manager), $);

    uint256 totalWeight = manager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(totalWeight)));
    vm.store(address(manager), $, newOpAndWeight);
    manager.getGovernorWeight(gov);
  }
}
