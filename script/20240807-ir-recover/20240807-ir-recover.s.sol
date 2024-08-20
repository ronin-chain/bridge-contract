// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { cheatBroadcast } from "@fdk/utils/Helpers.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TNetwork } from "@fdk/types/Types.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Migration } from "../Migration.s.sol";
import { LibProposal } from "../shared/libraries/LibProposal.sol";
import { LibStorage } from "../shared/libraries/LibStorage.sol";

import { TransparentUpgradeableProxyV2, TransparentUpgradeableProxy } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { IBridgeManagerCallback } from "@ronin/contracts/interfaces/bridge/IBridgeManagerCallback.sol";

import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";
import { TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

contract Migration__20240807_IR_Recover is Migration {
  using LibProxy for *;
  using LibCompanionNetwork for TNetwork;

  TNetwork _companionNetwork;
  TNetwork _prevNetwork;
  uint256 _prevForkId;

  address private constant SM_GOVERNOR = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;
  address private _multisigEth = 0x51F6696Ae42C6C40CA9F5955EcA2aaaB1Cefb26e;
  IMainchainBridgeManager private _mainchainBM = IMainchainBridgeManager(0x2Cf3CFb17774Ce0CFa34bB3f3761904e7fc3FaDB);
  TransparentUpgradeableProxyV2 private _mainchainBMproxy = TransparentUpgradeableProxyV2(payable(address(_mainchainBM)));
  IMainchainGatewayV3 private _mainchainGW = IMainchainGatewayV3(0x64192819Ac13Ef72bF6b5AE239AC672B43a9AF08);
  IRoninBridgeManager private _roninBM = IRoninBridgeManager(0x2ae89936FC398AeA23c63dB2404018fE361A8628);

  // address _prevBMLogic;
  // address _newBMLogic;
  address _newGWLogic;

  Proposal.ProposalDetail private _proposal;

  function run() public virtual onlyOn(DefaultNetwork.RoninMainnet.key()) {
    TNetwork currentNetwork = network();
    (, _companionNetwork) = currentNetwork.companionNetworkData();
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);

    {
      _preCheck_Withdrawable();
      _perform_PrankFix();
      _perform_checkAfterPrankFix();
    }

    switchBack(prevNetwork, prevForkId);

    _performCreateProposalOnRonin();
  }

  function _perform_PrankFix() internal {
    vm.prank(_multisigEth);
    // _prevBMLogic = _mainchainBMproxy.implementation();
    // _newBMLogic = _deployLogic(Contract.MainchainBridgeManager.key());
    _newGWLogic = _deployLogic(Contract.MainchainGatewayV3.key());

    (bool success, bytes memory ret) = address(_mainchainGW).staticcall(abi.encodeWithSignature("paused()"));
    if (!success) {
      revert("Cannot check if gateway is paused");
    }
    bool paused = abi.decode(ret, (bool));
    assertTrue(paused, "Gateway should be on paused");

    _recover_relayProposalWithCheatGovernors();

    // // 1. Upgrade to new version and call hotfix
    // cheatBroadcast(
    //   _multisigEth,
    //   address(_mainchainBMproxy),
    //   0,
    //   abi.encodeCall(
    //     TransparentUpgradeableProxy.upgradeToAndCall,
    //     (
    //       _newBMLogic,
    //       abi.encodeWithSelector(MainchainBridgeManager.hotfix__ir_recover.selector)
    //     )
    //   )
    // );

    // // 2. Downgrade to previous version
    // cheatBroadcast({
    //   from: _multisigEth,
    //   to: address(_mainchainBMproxy),
    //   callValue: 0,
    //   callData: abi.encodeWithSignature(
    //     "upgradeTo(address)",
    //     _prevBMLogic
    //   )
    // });
  }

  function _performCreateProposalOnRonin() internal {
    vm.startBroadcast(SM_GOVERNOR);
    _roninBM.propose({
      chainId: _proposal.chainId,
      expiryTimestamp: _proposal.expiryTimestamp,
      executor: _proposal.executor,
      targets: _proposal.targets,
      values: _proposal.values,
      calldatas: _proposal.calldatas,
      gasAmounts: _proposal.gasAmounts
    });
    vm.stopBroadcast();
  }

  function _recover_relayProposalWithCheatGovernors() internal {
    // Create proposal
    _proposal = __recover_createProposal();

    // Validate proposal's gas amount
    LibProposal.verifyProposalGasAmount(address(_mainchainBM), _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.gasAmounts);

    // Validate proposal's execution
    LibProposal.verifyProposalExecutionMainchain({ governance: address(_mainchainBM), proposal: _proposal, shouldRevertState: false });
  }

  function __recover_createProposal() internal view returns (Proposal.ProposalDetail memory proposal) {
    // struct ProposalDetail {
    //   // Nonce to make sure proposals are executed in order
    //   uint256 nonce;
    //   // Value 0: all chain should run this proposal
    //   // Other values: only specific chain has to execute
    //   uint256 chainId;
    //   uint256 expiryTimestamp;
    //   // The address that execute the proposal after the proposal passes.
    //   // Leave this address as address(0) to auto-execute by the last valid vote.
    //   address executor;
    //   address[] targets;
    //   uint256[] values;
    //   bytes[] calldatas;
    //   uint256[] gasAmounts;
    // }

    proposal.nonce = 1;
    proposal.chainId = 1;
    proposal.expiryTimestamp = block.timestamp + 12 days;
    proposal.executor = SM_GOVERNOR;

    // proposal.targets = new address[](2);
    // proposal.values = new uint256[](2);
    // proposal.calldatas = new bytes[](2);
    // proposal.gasAmounts = new uint256[](2);

    // proposal.targets[0] = address(_mainchainBM);
    // proposal.values[0] = 0;
    // proposal.calldatas[0] = abi.encodeCall(
    //     TransparentUpgradeableProxy.upgradeToAndCall,
    //     (
    //       _newBMLogic,
    //       abi.encodeWithSelector(MainchainBridgeManager.hotfix__ir_recover.selector)
    //     )
    //   );
    // proposal.gasAmounts[0] = 4000000;

    // proposal.targets[1] = address(_mainchainBM);
    // proposal.values[1] = 0;
    // proposal.calldatas[1] = abi.encodeWithSignature("upgradeTo(address)", _prevBMLogic);
    // proposal.gasAmounts[1] = 1000000;
    (, address[] memory operators, uint96[] memory weights) = _mainchainBM.getFullBridgeOperatorInfos();
    bool[] memory addeds = new bool[](operators.length);
    for (uint256 i = 0; i < operators.length; i++) {
      addeds[i] = true;
    }

    proposal.targets = new address[](2);
    proposal.values = new uint256[](2);
    proposal.calldatas = new bytes[](2);
    proposal.gasAmounts = new uint256[](2);

    proposal.targets[0] = address(_mainchainGW);
    proposal.values[0] = 0;
    proposal.gasAmounts[0] = 2000000;
    proposal.calldatas[0] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", abi.encodeWithSelector(IBridgeManagerCallback.onBridgeOperatorsAdded.selector, operators, weights, addeds)
    );

    proposal.targets[1] = address(_mainchainGW);
    proposal.values[1] = 0;
    proposal.calldatas[1] = abi.encodeWithSignature("upgradeTo(address)", _newGWLogic);
    proposal.gasAmounts[1] = 1000000;
  }

  function _preCheck_Withdrawable() internal {

    uint256 snapshotId = vm.snapshot();

    _fake_unpause();

    Transfer.Receipt memory dummyReceipt = _generateReceipt();

    SignatureConsumer.Signature[] memory sigs = new SignatureConsumer.Signature[](1);
    sigs[0].v = 28;
    sigs[0].r = 0xb377fd3c624426b0ef33f110dfc9424e6444f9000e8d4a859cd9102e59834544;
    sigs[0].s = 0x2e7f1f124b131944db2982c70f5ffc4054326facbbca95f161f3f042b58f52f8;

    vm.expectEmit(true, false, false, false, address(_mainchainGW));
    emit IMainchainGatewayV3.Withdrew(bytes32(0), dummyReceipt);
    _mainchainGW.submitWithdrawal(dummyReceipt, sigs);

    bool reverted = vm.revertTo(snapshotId);
    require(reverted, string.concat("Cannot revert to snapshot id: ", vm.toString(snapshotId)));
  }

  function _fake_unpause() internal {
    address pauseEnforcer = 0xe514d9DEB7966c8BE0ca922de8a064264eA6bcd4;
    console.log("Pranking Pause Enforcer");
    vm.prank(pauseEnforcer);
    (bool success,) = address(_mainchainGW).call(abi.encodeWithSignature("unpause()"));
    require(success, "Cannot unpause mainchain gateway");
    console.log("Stop pranking Pause Enforcer");
  }

  function _perform_checkAfterPrankFix() internal {
    // - Total weight in `BM` and `GW` the same
    {
      uint256 totalWeightBM = _mainchainBM.getTotalWeight();
      uint96 totalWeightGW = getGWTotalWeight();
      require(totalWeightBM == uint256(totalWeightGW), "Mismatched total weight");
    }

    // - Weight of all operators in `BM` and `GW` the same
    (, address[] memory operatorsBM, uint96[] memory weightsBM) = _mainchainBM.getFullBridgeOperatorInfos();
    for (uint256 i = 0; i < operatorsBM.length; i++) {
      require(getGWWeight(operatorsBM[i]) == weightsBM[i], "Mismatched weight");
    }

    {
      _postCheck_Withdrawable();
    }
  }

  function _postCheck_Withdrawable() internal {
    uint256 snapshotId = vm.snapshot();
    _fake_unpause();

    Transfer.Receipt memory dummyReceipt = _generateReceipt();

    SignatureConsumer.Signature[] memory sigs = new SignatureConsumer.Signature[](1);
    sigs[0].v = 28;
    sigs[0].r = 0xb377fd3c624426b0ef33f110dfc9424e6444f9000e8d4a859cd9102e59834544;
    sigs[0].s = 0x2e7f1f124b131944db2982c70f5ffc4054326facbbca95f161f3f042b58f52f8;

    vm.expectRevert(abi.encodeWithSelector(IMainchainGatewayV3.ErrInvalidSigner.selector, 0x11219E77CB5dF1E33e6e2985830d9Ef07f513f02, 0, sigs[0]));
    _mainchainGW.submitWithdrawal(dummyReceipt, sigs);

    bool reverted = vm.revertTo(snapshotId);
    require(reverted, string.concat("Cannot revert to snapshot id: ", vm.toString(snapshotId)));
  }

  function _postCheck() virtual override internal  {
    switchTo(_companionNetwork);

    // Cheat to unpause of MainchainGatewayV3 to self to pass post-check.
    _fake_unpause();

    // Cheat to change admin of MainchainBridgeManager to self to pass post-check.
    vm.prank(_multisigEth);
    TransparentUpgradeableProxy(payable(address(_mainchainBM))).changeAdmin(address(_mainchainBM));

    switchTo(DefaultNetwork.RoninMainnet.key());

    // Cheat to change admin of RoninBridgeManager to self to pass post-check.
    address payable roninBM = loadContract(Contract.RoninBridgeManager.key());
    address admin = roninBM.getProxyAdmin();
    vm.prank(admin);
    TransparentUpgradeableProxy(roninBM).changeAdmin(roninBM);

    super._postCheck();
  }

  function getGWTotalWeight() public view returns (uint96 totalWeight) {
    uint256 $$_operatorWeightSlot = 125;
    bytes32 paddedTotalWeight = vm.load(address(_mainchainGW), bytes32($$_operatorWeightSlot));
    totalWeight = uint96(uint256(paddedTotalWeight));
    console.log(string.concat("[STORAGE] Total weight in GW is ", vm.toString(totalWeight)));
  }

  function getGWWeight(address operator) public view returns (uint96 weight) {
    uint256 $$_operatorWeightSlot = 126;
    bytes32 $$ = LibStorage.getMappingElementSlotIndex(operator, $$_operatorWeightSlot);
    bytes32 paddedWeight = vm.load(address(_mainchainGW), $$);
    weight = uint96(uint256(paddedWeight));
    console.log(string.concat("[STORAGE] Weight of ", vm.toString(operator), " is ", vm.toString(weight)));
  }

  function _generateReceipt() internal returns (Transfer.Receipt memory receipt_) {
    // struct Receipt {
    //   uint256 id;
    //   Kind kind;
    //   TokenOwner mainchain;
    //   TokenOwner ronin;
    //   TokenInfo info;
    // }

    // struct TokenOwner {
    //   address addr;
    //   address tokenAddr;
    //   uint256 chainId;
    // }

    /* Receipt({
        id: 166631 [1.666e5],
        kind: 1,
        mainchain: TokenOwner({
            addr: 0x4Ab12E7CE31857Ee022f273e8580F73335a73c0B,
            tokenAddr: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            chainId: 1
        }),
        ronin: TokenOwner({
            addr: 0x03E1f309d281b0af1A17EBb29e89136c05b67206,
            tokenAddr: 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5,
            chainId: 2020
        }),
        info: TokenInfo({
            erc: 0,
            id: 0,
            quantity: 3996093750000000000000 [3.996e21]
        })
    }) */

    address mainchainETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address roninETH = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;

    receipt_.id = 133713371337;
    receipt_.kind = Transfer.Kind.Withdrawal;
    receipt_.mainchain.addr = makeAddr("recipient-mainchain");
    receipt_.mainchain.tokenAddr = mainchainETH;
    receipt_.mainchain.chainId = 1;
    receipt_.ronin.addr = makeAddr("recipient-ronin");
    receipt_.ronin.tokenAddr = roninETH;
    receipt_.ronin.chainId = 2020;
    receipt_.info.erc = TokenStandard.ERC20;
    receipt_.info.id = 0;
    receipt_.info.quantity = 3996093750000000000000;
  }
}
