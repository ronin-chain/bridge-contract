// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TNetwork, Network } from "script/utils/Network.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

abstract contract BasePostCheck is BaseMigration {
  using StdStyle for *;
  using LibArray for *;
  using LibProxy for *;

  uint256 internal seed = vm.unixTime();

  address payable internal bridgeSlash;
  address payable internal bridgeReward;
  address payable internal bridgeTracking;
  address payable internal roninBridgeManager;
  address payable internal roninGateway;
  address payable internal mainchainGateway;
  address payable internal mainchainBridgeManager;

  address internal cheatGovernor;
  address internal cheatOperator;
  uint256 internal cheatGovernorPk;
  uint256 internal cheatOperatorPk;

  bytes32 internal gwDomainSeparator;

  modifier onPostCheck(string memory postCheckLabel) {
    uint256 snapshotId = _beforePostCheck(postCheckLabel);
    _;
    _afterPostCheck(postCheckLabel, snapshotId);
  }

  modifier onlyOnRoninNetworkOrLocal() {
    require(
      block.chainid == DefaultNetwork.RoninMainnet.chainId() || block.chainid == DefaultNetwork.RoninTestnet.chainId()
        || block.chainid == Network.RoninDevnet.chainId() || block.chainid == DefaultNetwork.Local.chainId(),
      "chainid != RoninMainnet or RoninTestnet"
    );
    _;
  }

  function cheatAddOverWeightedGovernor(address manager) internal {
    uint256 totalWeight;
    try IBridgeManager(manager).getTotalWeight() returns (uint256 res) {
      totalWeight = res;
    } catch {
      (, bytes memory res) = manager.staticcall(abi.encodeWithSignature("getTotalWeights()"));
      totalWeight = abi.decode(res, (uint256));
    }
    uint256 cheatVoteWeight = totalWeight * 100;
    (cheatOperator, cheatOperatorPk) = makeAddrAndKey(string.concat("cheat-operator-", vm.toString(seed)));
    (cheatGovernor, cheatGovernorPk) = makeAddrAndKey(string.concat("cheat-governor-", vm.toString(seed)));

    vm.deal(cheatGovernor, 1); // Check created EOA
    vm.deal(cheatOperator, 1); // Check created EOA

    vm.prank(manager);
    try TransparentUpgradeableProxyV2(payable(manager)).functionDelegateCall(
      abi.encodeCall(
        IBridgeManager.addBridgeOperators,
        (cheatVoteWeight.toSingletonArray().toUint96sUnsafe(), cheatGovernor.toSingletonArray(), cheatOperator.toSingletonArray())
      )
    ) { } catch {
      vm.prank(manager);
      IBridgeManager(manager).addBridgeOperators(
        cheatVoteWeight.toSingletonArray().toUint96sUnsafe(), cheatGovernor.toSingletonArray(), cheatOperator.toSingletonArray()
      );
    }
  }

  function _beforePostCheck(string memory postCheckLabel) private returns (uint256 snapshotId) {
    snapshotId = vm.snapshot();
    console.log("\n> ".cyan(), postCheckLabel.blue().italic(), "...");
  }

  function _afterPostCheck(string memory postCheckLabel, uint256 snapshotId) private {
    console.log(string.concat("Postcheck ", postCheckLabel.italic(), " successful!\n").green());
    bool reverted = vm.revertTo(snapshotId);
    assertTrue(reverted, string.concat("Cannot revert to snapshot id: ", vm.toString(snapshotId)));
  }
}
