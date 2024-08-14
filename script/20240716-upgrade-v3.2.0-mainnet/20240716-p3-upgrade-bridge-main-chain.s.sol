// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IRoninBridgeManager } from "script/interfaces/IRoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IMainchainBridgeManager } from "script/interfaces/IMainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "script/contracts/MainchainBridgeManagerDeploy.s.sol";
import "script/contracts/MainchainWethUnwrapperDeploy.s.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

import "./20240716-helper.s.sol";
import "./20240716-operators-key.s.sol";
import "./wbtc-threshold.s.sol";
import { Migration } from "../Migration.s.sol";

contract Migration__20240716_P3_UpgradeBridgeMainchain is Migration, Migration__20240716_GovernorsKey, Migration__MapToken_WBTC_Threshold {
  using StdStyle for *;

  IRoninBridgeManager _oldRoninBridgeManager;
  IRoninBridgeManager _newwRoninBridgeManager;
  IMainchainBridgeManager _currMainchainBridgeManager;
  IMainchainBridgeManager _newMainchainBridgeManager;

  TNetwork _currentNetwork;
  TNetwork _companionNetwork;

  LegacyProposalDetail _mainchainProposal;

  address private _proposer;

  function run() public virtual onlyOn(DefaultNetwork.RoninMainnet.key()) {
    console.log("=== Starting migration Mainchain".bold().cyan());

    _newwRoninBridgeManager = IRoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
    // _currMainchainBridgeManager = IMainchainBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));

    _currentNetwork = network();
    _companionNetwork = config.getCompanionNetwork(_currentNetwork);
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);
    {
      // address companionManager = loadContract(Contract.MainchainBridgeManager.key());

      _currMainchainBridgeManager = IMainchainBridgeManager(0xa71456fA88a5f6a4696D0446E690Db4a5913fab0);
      // _currMainchainBridgeManager = IMainchainBridgeManager(companionManager); // TODO: resolve later
    }
    console.log("@@@ Switch to Ronin");
    console.log("Current network:", vm.toString(TNetwork.unwrap(_currentNetwork)));
    console.log("Prev network:", vm.toString(TNetwork.unwrap(prevNetwork)));
    switchBack(_currentNetwork, prevForkId);

    _oldRoninBridgeManager = IRoninBridgeManager(0x5FA49E6CA54a9daa8eCa4F403ADBDE5ee075D84a);
    _proposer = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // SM Governor

    // _deployMainchainBridgeManager();
    _newMainchainBridgeManager = IMainchainBridgeManager(0x2Cf3CFb17774Ce0CFa34bB3f3761904e7fc3FaDB);

    _prankChangeAdminMainchainBM();
    _upgradeBridgeMainchain();
  }

  function _prankChangeAdminMainchainBM() internal {
    console.log("@@@ Switch to companion");
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);

    address bmProxyAdmin = LibProxy.getProxyAdmin(payable(address(_newMainchainBridgeManager)));
    vm.prank(bmProxyAdmin);
    TransparentUpgradeableProxy(payable(address(_newMainchainBridgeManager))).changeAdmin(address(_currMainchainBridgeManager));

    switchBack(prevNetwork, prevForkId);
  }

  /**
   * @dev Deploy Mainchain Bridge Manager and transfer proxy admin to current BM
   */
  function _deployMainchainBridgeManager() internal returns (address mainchainBM) {
    console.log("@@@ Switch to companion");
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);

    ISharedArgument.SharedParameter memory param;

    {
      (address[] memory currGovernors, address[] memory currOperators, uint96[] memory currWeights) = _currMainchainBridgeManager.getFullBridgeOperatorInfos();
      uint totalCurrGovernors = currGovernors.length;
      param.mainchainBridgeManager.bridgeOperators = new address[](totalCurrGovernors);
      param.mainchainBridgeManager.governors = new address[](totalCurrGovernors);
      param.mainchainBridgeManager.voteWeights = new uint96[](totalCurrGovernors);

      for (uint i = 0; i < totalCurrGovernors; i++) {
        param.mainchainBridgeManager.bridgeOperators[i] = currOperators[i];
        param.mainchainBridgeManager.governors[i] = currGovernors[i];
        param.mainchainBridgeManager.voteWeights[i] = currWeights[i];
      }
    }

    param.mainchainBridgeManager.num = 7;
    param.mainchainBridgeManager.denom = 10;
    param.mainchainBridgeManager.roninChainId = 2020;
    param.mainchainBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
    param.mainchainBridgeManager.bridgeContract = loadContract(Contract.MainchainGatewayV3.key());

    param.mainchainBridgeManager.targetOptions = new GlobalProposal.TargetOption[](2);
    param.mainchainBridgeManager.targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    param.mainchainBridgeManager.targetOptions[1] = GlobalProposal.TargetOption.PauseEnforcer;

    param.mainchainBridgeManager.targets = new address[](2);
    param.mainchainBridgeManager.targets[0] = loadContract(Contract.MainchainGatewayV3.key());
    param.mainchainBridgeManager.targets[1] = loadContract(Contract.MainchainPauseEnforcer.key());

    _newMainchainBridgeManager = IMainchainBridgeManager(
      new MainchainBridgeManagerDeploy().overrideArgs(
        abi.encodeCall(
          _newMainchainBridgeManager.initialize,
          (
            param.mainchainBridgeManager.num,
            param.mainchainBridgeManager.denom,
            param.mainchainBridgeManager.roninChainId,
            param.mainchainBridgeManager.bridgeContract,
            new address[](0),
            param.mainchainBridgeManager.bridgeOperators,
            param.mainchainBridgeManager.governors,
            param.mainchainBridgeManager.voteWeights,
            param.mainchainBridgeManager.targetOptions,
            param.mainchainBridgeManager.targets
          )
        )
      ).run()
    );

    address proxyAdmin = LibProxy.getProxyAdmin(payable(address(_newMainchainBridgeManager)));
    vm.broadcast(proxyAdmin);
    TransparentUpgradeableProxy(payable(address(_newMainchainBridgeManager))).changeAdmin(address(_currMainchainBridgeManager));
    // TransparentUpgradeableProxy(payable(address(_newMainchainBridgeManager))).changeAdmin(address(_newMainchainBridgeManager));

    switchBack(prevNetwork, prevForkId);
  }

  /**
   * @dev Create proposal on mainchain
   *
   */
  function _upgradeBridgeMainchain() internal {
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);

    // address weth = loadContract(Contract.WETH.key());
    // address wethUnwrapper = new MainchainWethUnwrapperDeploy().overrideArgs(abi.encode(weth)).run();
    address wethUnwrapper = 0x8048b12511d9BE6e4e094089b12f54923C4E2F83;

    address mainchainGatewayV3Logic = 0xfc274EC92bBb1A1472884558d1B5CaaC6F8220Ee;
    address mainchainGatewayV3Proxy = loadContract(Contract.MainchainGatewayV3.key());

    ISharedArgument.SharedParameter memory param;
    param.mainchainBridgeManager.callbackRegisters = new address[](1);
    param.mainchainBridgeManager.callbackRegisters[0] = loadContract(Contract.MainchainGatewayV3.key());

    uint256 expiredTime = 1723481999; // Wed Aug 12 2024 23:59:59 GMT+0700 (Indochina Time)
    // uint256 expiredTime = block.timestamp + 14 days;
    uint N = 6;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = mainchainGatewayV3Proxy;
    // Mapping WBTC calldata
    {
      address[] memory mainchainTokens = new address[](1);
      address[] memory roninTokens = new address[](1);
      TokenStandard[] memory standards = new TokenStandard[](1);
      uint256[][4] memory thresholds;

      mainchainTokens[0] = _wbtcMainchainToken;
      roninTokens[0] = _wbtcRoninToken;
      standards[0] = TokenStandard.ERC20;
      // highTierThreshold
      thresholds[0] = new uint256[](1);
      thresholds[0][0] = _wbtcHighTierThreshold;
      // lockedThreshold
      thresholds[1] = new uint256[](1);
      thresholds[1][0] = _wbtcLockedThreshold;
      // unlockFeePercentages
      thresholds[2] = new uint256[](1);
      thresholds[2][0] = _wbtcUnlockFeePercentages;
      // dailyWithdrawalLimit
      thresholds[3] = new uint256[](1);
      thresholds[3][0] = _wbtcDailyWithdrawalLimit;

      calldatas[0] = abi.encodeWithSignature(
        "functionDelegateCall(bytes)", abi.encodeCall(IMainchainGatewayV3.mapTokensAndThresholds, (mainchainTokens, roninTokens, standards, thresholds))
      );
    }

    targets[1] = mainchainGatewayV3Proxy;
    calldatas[1] =
      abi.encodeWithSignature("upgradeToAndCall(address,bytes)", mainchainGatewayV3Logic, abi.encodeWithSignature("initializeV4(address)", wethUnwrapper));

    targets[2] = mainchainGatewayV3Proxy;
    calldatas[2] =
      abi.encodeWithSignature("functionDelegateCall(bytes)", (abi.encodeWithSignature("setContract(uint8,address)", 11, address(_newMainchainBridgeManager))));

    // Do all setting steps before migrating to change admin
    targets[3] = mainchainGatewayV3Proxy;
    calldatas[3] = abi.encodeWithSignature("changeAdmin(address)", address(_newMainchainBridgeManager));

    targets[4] = address(_newMainchainBridgeManager);
    calldatas[4] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", (abi.encodeWithSignature("registerCallbacks(address[])", param.mainchainBridgeManager.callbackRegisters))
    );

    targets[5] = address(_newMainchainBridgeManager);
    calldatas[5] = abi.encodeWithSignature("changeAdmin(address)", address(_newMainchainBridgeManager));

    for (uint i; i < N; ++i) {
      gasAmounts[i] = 1_000_000;
    }

    _mainchainProposal.nonce = _currMainchainBridgeManager.round(Network.EthMainnet.chainId()) + 1;
    _mainchainProposal.chainId = Network.EthMainnet.chainId();
    _mainchainProposal.expiryTimestamp = expiredTime;
    _mainchainProposal.targets = targets;
    _mainchainProposal.values = values;
    _mainchainProposal.calldatas = calldatas;
    _mainchainProposal.gasAmounts = gasAmounts;

    switchBack(prevNetwork, prevForkId);

    vm.startBroadcast(_proposer);
    (bool success,) = address(_oldRoninBridgeManager).call(
      abi.encodeWithSignature(
        "propose(uint256,uint256,address[],uint256[],bytes[],uint256[])",
        _mainchainProposal.chainId,
        _mainchainProposal.expiryTimestamp,
        _mainchainProposal.targets,
        _mainchainProposal.values,
        _mainchainProposal.calldatas,
        _mainchainProposal.gasAmounts
      )
    );
    require(success, "Failed to propose");
    vm.stopBroadcast();
  }

  function _postCheck() internal virtual override {
    console.log("Starting post-check".bold().cyan());
    _simulateProposal(_mainchainProposal);

    super._postCheck();
  }

  function getDomain() public pure returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", 2020)) // salt
      )
    );
  }

  function _generateSignaturesFor(
    bytes32 domain,
    bytes32 proposalHash,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) public pure returns (Signature[] memory sigs) {
    sigs = new Signature[](signerPKs.length);

    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = ECDSA.toTypedDataHash(domain, Ballot.hash(proposalHash, support));
      sigs[i] = _sign(signerPKs[i], digest);
    }
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (Signature memory sig) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig.v = v;
    sig.r = r;
    sig.s = s;
  }

  function hashLegacyProposal(LegacyProposalDetail memory proposal) public pure returns (bytes32 digest_) {
    bytes32 TYPE_HASH = 0xd051578048e6ff0bbc9fca3b65a42088dbde10f36ca841de566711087ad9b08a;

    uint256[] memory values = proposal.values;
    address[] memory targets = proposal.targets;
    bytes32[] memory calldataHashList = new bytes32[](proposal.calldatas.length);
    uint256[] memory gasAmounts = proposal.gasAmounts;

    for (uint256 i; i < calldataHashList.length; ++i) {
      calldataHashList[i] = keccak256(proposal.calldatas[i]);
    }

    assembly {
      let ptr := mload(0x40)
      mstore(ptr, TYPE_HASH)
      mstore(add(ptr, 0x20), mload(proposal)) // _proposal.nonce
      mstore(add(ptr, 0x40), mload(add(proposal, 0x20))) // _proposal.chainId
      mstore(add(ptr, 0x60), mload(add(proposal, 0x40))) // expiry timestamp

      let arrayHashed
      arrayHashed := keccak256(add(targets, 32), mul(mload(targets), 32)) // targetsHash
      mstore(add(ptr, 0x80), arrayHashed)
      arrayHashed := keccak256(add(values, 32), mul(mload(values), 32)) // _valuesHash
      mstore(add(ptr, 0xa0), arrayHashed)
      arrayHashed := keccak256(add(calldataHashList, 32), mul(mload(calldataHashList), 32)) // _calldatasHash
      mstore(add(ptr, 0xc0), arrayHashed)
      arrayHashed := keccak256(add(gasAmounts, 32), mul(mload(gasAmounts), 32)) // _gasAmountsHash
      mstore(add(ptr, 0xe0), arrayHashed)
      digest_ := keccak256(ptr, 0x100)
    }
  }

  function _simulateProposal(LegacyProposalDetail memory proposal) internal {
    (TNetwork prevNetwork, uint256 prevForkId) = switchTo(_companionNetwork);

    Ballot.VoteType[] memory cheatingSupports = new Ballot.VoteType[](1);
    uint256[] memory cheatingPks = new uint256[](1);
    (address cheatingGov, uint256 cheatingGovPk) = makeAddrAndKey("Governor");

    cheatingSupports[0] = Ballot.VoteType.For;
    cheatingPks[0] = cheatingGovPk;
    Signature[] memory cheatingSignatures = _generateSignaturesFor(getDomain(), hashLegacyProposal(proposal), cheatingPks, Ballot.VoteType.For);

    uint256 totalGas = 1_000_000;
    for (uint256 i; i < proposal.gasAmounts.length; ++i) {
      totalGas += proposal.gasAmounts[i];
    }

    _cheatWeightGovernor(IBridgeManager(address(_currMainchainBridgeManager)), cheatingGov);

    vm.prank(cheatingGov);
    (bool success,) = address(_currMainchainBridgeManager).call{ gas: totalGas }(
      abi.encodeWithSignature(
        "relayProposal((uint256,uint256,uint256,address[],uint256[],bytes[],uint256[]),uint8[],(uint8,bytes32,bytes32)[])",
        proposal,
        cheatingSupports,
        cheatingSignatures
      )
    );
    require(success, "Failed to relay proposal");
  }

  function _cheatWeightGovernor(IBridgeManager manager, address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(manager), $);

    uint256 totalWeight = manager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(manager), $, newOpAndWeight);

    assert(manager.getGovernorWeight(gov) == totalWeight);
  }
}
