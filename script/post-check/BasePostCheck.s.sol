// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TNetwork, Network } from "script/utils/Network.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { ITransparentUpgradeableProxyV2 } from "script/interfaces/ITransparentUpgradeableProxyV2.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";

abstract contract BasePostCheck is BaseMigration, SignatureConsumer {
  using StdStyle for *;
  using LibArray for *;
  using LibProxy for *;
  using stdStorage for StdStorage;

  uint256 internal seed = vm.unixTime();

  address payable internal brSl;
  address payable internal brRw;
  address payable internal brTk;
  address payable internal ronBM;
  address payable internal ronGW;
  address payable internal ethGW;
  address payable internal ethBM;

  address internal cheatGv;
  address internal cheatOp;

  address[] internal mockGvs;
  address[] internal mockOps;

  bytes32 internal gwDomainHash;

  modifier onPostCheck(
    string memory postCheckLabel
  ) {
    uint256 snapshotId = _beforePostCheck(postCheckLabel);
    _;
    _afterPostCheck(postCheckLabel, snapshotId);
  }

  modifier onlyOnRoninNetworkOrLocal() {
    require(
      block.chainid == DefaultNetwork.RoninMainnet.chainId() || block.chainid == DefaultNetwork.RoninTestnet.chainId()
        || block.chainid == Network.RoninDevnet.chainId() || block.chainid == DefaultNetwork.LocalHost.chainId(),
      "chainid != RoninMainnet or RoninTestnet"
    );
    _;
  }

  function cheatAddOverWeightedGovernor(
    address bm
  ) internal {
    uint256 totalWeight;
    try IBridgeManager(bm).getTotalWeight() returns (uint256 res) {
      totalWeight = res;
    } catch {
      (, bytes memory res) = bm.staticcall(abi.encodeWithSignature("getTotalWeights()"));
      totalWeight = abi.decode(res, (uint256));
    }

    uint256 cheatVW = totalWeight * 100;
    uint256 cheatOpPK;
    uint256 cheatGvPK;

    (cheatOp, cheatOpPK) = makeAddrAndKey(string.concat("cheat-op-", vm.toString(seed)));
    (cheatGv, cheatGvPK) = makeAddrAndKey(string.concat("cheat-gv-", vm.toString(seed)));

    vm.rememberKey(cheatOpPK);
    vm.rememberKey(cheatGvPK);

    vm.deal(cheatGv, 1); // Check created EOA
    vm.deal(cheatOp, 1); // Check created EOA

    address pa = bm.getProxyAdmin();
    if (pa != bm) {
      console.log(unicode"⚠ WARNING: ProxyAdmin is not the bm!".yellow());
    }
    vm.prank(pa);
    try ITransparentUpgradeableProxyV2(bm).functionDelegateCall(
      abi.encodeCall(IBridgeManager.addBridgeOperators, (cheatVW.toSingletonArray().toUint96sUnsafe(), cheatGv.toSingletonArray(), cheatOp.toSingletonArray()))
    ) { } catch {
      vm.prank(pa);
      IBridgeManager(bm).addBridgeOperators(cheatVW.toSingletonArray().toUint96sUnsafe(), cheatGv.toSingletonArray(), cheatOp.toSingletonArray());
    }
  }

  function overrideMockBOs(
    address bm
  ) internal {
    uint256 boCount = IBridgeManager(bm).totalBridgeOperator();
    address[] memory bos = IBridgeManager(bm).getBridgeOperators();
    uint96[] memory vws = new uint96[](boCount);

    delete mockGvs;
    delete mockOps;

    for (uint256 i; i < boCount; ++i) {
      vws[i] = IBridgeManager(bm).getBridgeOperatorWeight(bos[i]);
      require(vws[i] > 0, "BridgeOperator weight should be greater than 0");

      (address gv, uint256 gvPK) = makeAddrAndKey(string.concat("mock-gv-", vm.toString(vm.unixTime()), "-", vm.toString(i)));
      (address op, uint256 opPK) = makeAddrAndKey(string.concat("mock-op-", vm.toString(vm.unixTime()), "-", vm.toString(i)));

      vm.rememberKey(gvPK);
      vm.rememberKey(opPK);

      mockGvs.push(gv);
      mockOps.push(op);
    }

    address pa = bm.getProxyAdmin();
    vm.prank(pa);
    try ITransparentUpgradeableProxyV2(bm).functionDelegateCall(abi.encodeCall(IBridgeManager.addBridgeOperators, (vws, mockGvs, mockOps))) { }
    catch {
      vm.prank(pa);
      IBridgeManager(bm).addBridgeOperators(vws, mockGvs, mockOps);
    }

    // remove real bridge operators
    vm.prank(pa);
    try ITransparentUpgradeableProxyV2(bm).functionDelegateCall(abi.encodeCall(IBridgeManager.removeBridgeOperators, (bos))) { }
    catch {
      vm.prank(pa);
      IBridgeManager(bm).removeBridgeOperators(bos);
    }
  }

  // Set the balance of an account for any ERC20 token
  // Use the alternative signature to update `totalSupply`
  function deal(address token, address to, uint256 give) internal virtual {
    deal(token, to, give, false);
  }

  function dealERC721(address token, address to, uint256 id) internal virtual {
    // check if token id is already minted and the actual owner.
    (bool successMinted, bytes memory ownerData) = token.staticcall(abi.encodeWithSelector(0x6352211e, id));
    require(successMinted, "StdCheats deal(address,address,uint,bool): id not minted.");

    // get owner current balance
    (, bytes memory fromBalData) = token.staticcall(abi.encodeWithSelector(0x70a08231, abi.decode(ownerData, (address))));
    uint256 fromPrevBal = abi.decode(fromBalData, (uint256));

    // get new user current balance
    (, bytes memory toBalData) = token.staticcall(abi.encodeWithSelector(0x70a08231, to));
    uint256 toPrevBal = abi.decode(toBalData, (uint256));

    // update balances
    stdstore.target(token).sig(0x70a08231).with_key(abi.decode(ownerData, (address))).checked_write(--fromPrevBal);
    stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(++toPrevBal);

    // update owner
    stdstore.target(token).sig(0x6352211e).with_key(id).checked_write(to);
  }

  function deal(address token, address to, uint256 give, bool adjust) internal virtual {
    // get current balance
    (, bytes memory balData) = token.staticcall(abi.encodeWithSelector(0x70a08231, to));
    uint256 prevBal = abi.decode(balData, (uint256));

    // update balance
    stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(give);

    // update total supply
    if (adjust) {
      (, bytes memory totSupData) = token.staticcall(abi.encodeWithSelector(0x18160ddd));
      uint256 totSup = abi.decode(totSupData, (uint256));
      if (give < prevBal) {
        totSup -= (prevBal - give);
      } else {
        totSup += (give - prevBal);
      }
      stdstore.target(token).sig(0x18160ddd).checked_write(totSup);
    }
  }

  function _beforePostCheck(
    string memory postCheckLabel
  ) private returns (uint256 snapshotId) {
    snapshotId = vm.snapshot();
    console.log("\n> ".cyan(), postCheckLabel.blue().italic(), "...");
  }

  function _afterPostCheck(string memory postCheckLabel, uint256 snapshotId) private {
    console.log(string.concat("Postcheck ", postCheckLabel.italic(), " successful!\n").green());
    bool reverted = vm.revertTo(snapshotId);
    assertTrue(reverted, string.concat("Cannot revert to snapshot id: ", vm.toString(snapshotId)));
  }
}
