// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240716-p2-upgrade-bridge-ronin-chain.s.sol";
import "./20240716-p3-upgrade-bridge-main-chain.s.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";

contract Verify_Script_20240716 is Migration__20240716_P2_UpgradeBridgeRoninchain, Migration__20240716_P3_UpgradeBridgeMainchain {
  using StdStyle for *;

  function run() public override(Migration__20240716_P2_UpgradeBridgeRoninchain, Migration__20240716_P3_UpgradeBridgeMainchain) {
    TNetwork currentNetwork = network();
    TNetwork companionNetwork = config.getCompanionNetwork(currentNetwork);

    console.log("*** Verify proposal Ronin chain ***".bold().cyan());
    Migration__20240716_P2_UpgradeBridgeRoninchain.run();

    console.log("*** Verify proposal Main chain ***".bold().cyan());
    Migration__20240716_P3_UpgradeBridgeMainchain.run();
    // switchBack(prevNetwork, prevForkId);
  }

  function _postCheck() internal virtual override(Migration__20240716_P2_UpgradeBridgeRoninchain, Migration__20240716_P3_UpgradeBridgeMainchain) {
    console.log("*********** Starting post-check ************".bold().cyan());

    console.log("****** Finalize proposal Ronin chain ******".bold().cyan());
    _helperVoteForCurrentNetwork(_roninProposal);

    console.log("****** Finalize proposal Main chain ******".bold().cyan());
    _simulateProposal(_mainchainProposal);

    Migration._postCheck();
  }
}
