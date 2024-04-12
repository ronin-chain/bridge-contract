// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Migration } from "../Migration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { Migration_01_Deploy_RoninBridge } from "./01_Deploy_RoninBridge.s.sol";
import { LibCompanionNetwork } from "../shared/libraries/LibCompanionNetwork.sol";
import { Migration_02_Deploy_MainchainBridge } from "./02_Deploy_MainchainBridge.s.sol";

contract Deploy_v0_3_1 is Migration {
  using LibCompanionNetwork for *;

  function run() external {
    TNetwork currentNetwork = network();
    TNetwork companionNetwork = currentNetwork.companionNetwork();

    if (
      currentNetwork == DefaultNetwork.RoninMainnet.key() || currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == Network.RoninDevnet.key()
    ) {
      new Migration_01_Deploy_RoninBridge().run();

      config.createFork(companionNetwork);
      config.switchTo(companionNetwork);

      new Migration_02_Deploy_MainchainBridge().run();

      config.switchTo(currentNetwork);
    } else if (currentNetwork == Network.EthMainnet.key() || currentNetwork == Network.Goerli.key() || currentNetwork == Network.Sepolia.key()) {
      config.createFork(companionNetwork);
      config.switchTo(companionNetwork);

      new Migration_01_Deploy_RoninBridge().run();

      config.switchTo(currentNetwork);

      new Migration_02_Deploy_MainchainBridge().run();
    } else if (currentNetwork == DefaultNetwork.Local.key()) {
      new Migration_01_Deploy_RoninBridge().run();
      new Migration_02_Deploy_MainchainBridge().run();
    } else {
      revert("Unsupported network");
    }
  }
}
