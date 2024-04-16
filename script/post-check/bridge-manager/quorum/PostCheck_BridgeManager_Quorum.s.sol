// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IQuorum } from "@ronin/contracts/interfaces/IQuorum.sol";
import { BasePostCheck } from "script/post-check/BasePostCheck.s.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { Contract } from "script/utils/Contract.sol";
import { TNetwork } from "@fdk/types/Types.sol";
import { Network } from "script/utils/Network.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

abstract contract PostCheck_BridgeManager_Quorum is BasePostCheck {
  using LibArray for *;
  using LibCompanionNetwork for *;

  function _validate_BridgeManager_Quorum() internal {
    validate_NonZero_MinimumVoteWeight();
  }

  function validate_NonZero_MinimumVoteWeight() private onlyOnRoninNetworkOrLocal onPostCheck("validate_NonZero_MinimumVoteWeight") {
    assertTrue(IQuorum(roninBridgeManager).minimumVoteWeight() > 0, "Ronin: Minimum vote weight must be greater than 0");
    TNetwork currentNetwork = network();

    (, TNetwork companionNetwork) = currentNetwork.companionNetworkData();
    CONFIG.createFork(companionNetwork);
    CONFIG.switchTo(companionNetwork);

    assertTrue(IQuorum(mainchainBridgeManager).minimumVoteWeight() > 0, "Mainchain: Minimum vote weight must be greater than 0");

    CONFIG.switchTo(currentNetwork);
  }
}
