// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { DefaultContract } from "foundry-deployment-kit/utils/DefaultContract.sol";
import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import "@ronin/script/contracts/MainchainWethUnwrapperDeploy.s.sol";

import "./20240411-operators-key.s.sol";
import "../BridgeMigration.sol";

struct LegacyProposalDetail {
  uint256 nonce;
  uint256 chainId;
  uint256 expiryTimestamp;
  address[] targets;
  uint256[] values;
  bytes[] calldatas;
  uint256[] gasAmounts;
}

contract Migration__20240409_P3_UpgradeBridgeMainchain is BridgeMigration, Migration__20240409_GovernorsKey {
  ISharedArgument.SharedParameter _param;
  MainchainBridgeManager _currMainchainBridgeManager;
  MainchainBridgeManager _newMainchainBridgeManager;

  address private _governor;
  address[] private _voters;

  address PROXY_ADMIN = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;


  function setUp() public override {
    super.setUp();
    CONFIG.setAddress(network(), DefaultContract.ProxyAdmin.key(), PROXY_ADMIN);

    _currMainchainBridgeManager = MainchainBridgeManager(_config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key()));
  }

  function run() public onlyOn(Network.Sepolia.key()) {
    _governor = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _voters.push(0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    _voters.push(0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    _voters.push(0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);

    _changeTempAdmin();
    _deployMainchainBridgeManager();
    _upgradeBridge();
  }

  function _changeTempAdmin() internal {
    address pauseEnforcerProxy = _config.getAddressFromCurrentNetwork(Contract.MainchainPauseEnforcer.key());
    address mainchainGatewayV3Proxy = _config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());

    vm.startBroadcast(0x968D0Cd7343f711216817E617d3f92a23dC91c07);
    address(pauseEnforcerProxy).call(abi.encodeWithSignature("changeAdmin(address)", _currMainchainBridgeManager));
    address(mainchainGatewayV3Proxy).call(abi.encodeWithSignature("changeAdmin(address)", _currMainchainBridgeManager));
    vm.stopBroadcast();
  }

  function _upgradeBridge() internal {
    _newMainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    address weth = _config.getAddressFromCurrentNetwork(Contract.WETH.key());
    address wethUnwrapper = new MainchainWethUnwrapperDeploy().overrideArgs(abi.encode(weth)).run();

    address pauseEnforcerLogic = _deployLogic(Contract.MainchainPauseEnforcer.key());
    address mainchainGatewayV3Logic = _deployLogic(Contract.MainchainGatewayV3.key());

    address pauseEnforcerProxy = _config.getAddressFromCurrentNetwork(Contract.MainchainPauseEnforcer.key());
    address mainchainGatewayV3Proxy = _config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());

    uint256 expiredTime = block.timestamp + 14 days;
    uint N = 4;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = mainchainGatewayV3Proxy;
    targets[1] = mainchainGatewayV3Proxy;
    targets[2] = pauseEnforcerProxy;
    targets[3] = pauseEnforcerProxy;

    calldatas[0] = abi.encodeWithSignature(
      "upgradeToAndCall(address,bytes)",
      mainchainGatewayV3Logic,
      abi.encodeWithSelector(MainchainGatewayV3.initializeV4.selector, wethUnwrapper)
    );
    calldatas[1] = abi.encodeWithSignature("changeAdmin(address)", address(_newMainchainBridgeManager));
    calldatas[2] = abi.encodeWithSignature("upgradeTo(address)", pauseEnforcerLogic);
    calldatas[3] = abi.encodeWithSignature("changeAdmin(address)", address(_newMainchainBridgeManager));

    for (uint i; i < N; ++i) {
      gasAmounts[i] = 1_000_000;
    }

    LegacyProposalDetail memory proposal;
    proposal.nonce =  _currMainchainBridgeManager.round(block.chainid) + 1;
    proposal.chainId = block.chainid;
    proposal.expiryTimestamp = expiredTime;
    proposal.targets = targets;
    proposal.values = values;
    proposal.calldatas = calldatas;
    proposal.gasAmounts = gasAmounts;

    uint V = _voters.length + 1;
    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](V);
    for (uint i; i < V; ++i) {
      supports_[i] = Ballot.VoteType.For;
    }

    SignatureConsumer.Signature[] memory signatures = _generateSignaturesFor(
      getDomain(),
      hashLegacyProposal(proposal),
      _loadGovernorPKs(),
      Ballot.VoteType.For
    );

    vm.broadcast(_governor);
    address(_currMainchainBridgeManager).call(
      abi.encodeWithSignature(
        "relayProposal((uint256,uint256,uint256,address[],uint256[],bytes[],uint256[]),uint8[],(uint8,bytes32,bytes32)[])",
        proposal,
        supports_,
        signatures
      )
    );
 }

  function getDomain() pure public returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("2"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", 2021)) // salt
      )
    );
  }

  function _generateSignaturesFor(
    bytes32 domain,
    bytes32 proposalHash,
    uint256[] memory signerPKs,
    Ballot.VoteType support
  ) public view returns (SignatureConsumer.Signature[] memory sigs) {
    sigs = new SignatureConsumer.Signature[](signerPKs.length);

    for (uint256 i; i < signerPKs.length; i++) {
      bytes32 digest = ECDSA.toTypedDataHash(domain, Ballot.hash(proposalHash, support));
      sigs[i] = _sign(signerPKs[i], digest);
    }
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (SignatureConsumer.Signature memory sig) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig.v = v;
    sig.r = r;
    sig.s = s;
  }

  function hashLegacyProposal(LegacyProposalDetail memory proposal) pure public returns (bytes32 digest_) {
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

  function _deployMainchainBridgeManager() internal returns (address mainchainBM) {
    ISharedArgument.SharedParameter memory param;

    param.mainchainBridgeManager.num = 7;
    param.mainchainBridgeManager.denom = 10;
    param.mainchainBridgeManager.roninChainId = 2021;
    param.mainchainBridgeManager.expiryDuration = 60 * 60 * 24 * 14; // 14 days
    param.mainchainBridgeManager.bridgeContract = _config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());
    param.mainchainBridgeManager.bridgeOperators = new address[](4);
    param.mainchainBridgeManager.bridgeOperators[0] = 0x2e82D2b56f858f79DeeF11B160bFC4631873da2B;
    param.mainchainBridgeManager.bridgeOperators[1] = 0xBcb61783dd2403FE8cC9B89B27B1A9Bb03d040Cb;
    param.mainchainBridgeManager.bridgeOperators[2] = 0xB266Bf53Cf7EAc4E2065A404598DCB0E15E9462c;
    param.mainchainBridgeManager.bridgeOperators[3] = 0xcc5Fc5B6c8595F56306Da736F6CD02eD9141C84A;

    param.mainchainBridgeManager.governors = new address[](4);
    param.mainchainBridgeManager.governors[0] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    param.mainchainBridgeManager.governors[1] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    param.mainchainBridgeManager.governors[2] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    param.mainchainBridgeManager.governors[3] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    param.mainchainBridgeManager.voteWeights = new uint96[](4);
    param.mainchainBridgeManager.voteWeights[0] = 100;
    param.mainchainBridgeManager.voteWeights[1] = 100;
    param.mainchainBridgeManager.voteWeights[2] = 100;
    param.mainchainBridgeManager.voteWeights[3] = 100;

    param.mainchainBridgeManager.targetOptions = new GlobalProposal.TargetOption[](2);
    param.mainchainBridgeManager.targetOptions[0] = GlobalProposal.TargetOption.GatewayContract;
    param.mainchainBridgeManager.targetOptions[1] = GlobalProposal.TargetOption.PauseEnforcer;

    param.mainchainBridgeManager.targets = new address[](2);
    param.mainchainBridgeManager.targets[0] = _config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());
    param.mainchainBridgeManager.targets[1] = _config.getAddressFromCurrentNetwork(Contract.MainchainPauseEnforcer.key());

    _newMainchainBridgeManager = MainchainBridgeManager(new MainchainBridgeManagerDeploy().overrideArgs(
      abi.encodeCall(
        _newMainchainBridgeManager.initialize,
        (
          param.mainchainBridgeManager.num,
          param.mainchainBridgeManager.denom,
          param.mainchainBridgeManager.roninChainId,
          param.mainchainBridgeManager.bridgeContract,
          param.mainchainBridgeManager.callbackRegisters,
          param.mainchainBridgeManager.bridgeOperators,
          param.mainchainBridgeManager.governors,
          param.mainchainBridgeManager.voteWeights,
          param.mainchainBridgeManager.targetOptions,
          param.mainchainBridgeManager.targets
        )
      )
    ).run());
  }
}
