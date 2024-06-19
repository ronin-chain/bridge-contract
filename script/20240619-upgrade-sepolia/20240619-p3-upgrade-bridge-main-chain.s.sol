// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { MockSLP } from "@ronin/contracts/mocks/token/MockSLP.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";
import "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import "@ronin/script/contracts/MainchainWethUnwrapperDeploy.s.sol";

import "../20240411-upgrade-v3.2.0-testnet/20240411-helper.s.sol";
import "./20240619-operators-key.s.sol";
import "../Migration.s.sol";

contract Migration__20240619_P3_UpgradeBridgeMainchain is Migration, Migration__20240619_GovernorsKey {
  MainchainBridgeManager _mainchainBridgeManager;
  MainchainBridgeAdminUtils _mainchainProposalUtils;

  address private _governor;
  address[] private _voters;

  address TESTNET_ADMIN = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;

  function setUp() public virtual override {
    super.setUp();
  }

  function run() public virtual onlyOn(Network.Sepolia.key()) {
    CONFIG.setAddress(network(), DefaultContract.ProxyAdmin.key(), TESTNET_ADMIN);

    _mainchainBridgeManager = MainchainBridgeManager(config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key()));

    _governor = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    _voters.push(0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    _voters.push(0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    _voters.push(0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);

    _upgradeBridgeMainchain();
  }

  function _upgradeBridgeMainchain() internal {
    address mainchainGatewayV3Logic = _deployLogic(Contract.MainchainGatewayV3.key());
    address mainchainGatewayV3Proxy = config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());

    ISharedArgument.SharedParameter memory param;
    param.mainchainBridgeManager.callbackRegisters = new address[](1);
    param.mainchainBridgeManager.callbackRegisters[0] = config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());

    uint256 expiredTime = block.timestamp + 14 days;
    uint N = 1;
    address[] memory targets = new address[](N);
    uint256[] memory values = new uint256[](N);
    bytes[] memory calldatas = new bytes[](N);
    uint256[] memory gasAmounts = new uint256[](N);

    targets[0] = mainchainGatewayV3Proxy;
    calldatas[0] = abi.encodeWithSignature("upgradeTo(address)", mainchainGatewayV3Logic);
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    address[] memory governors = new address[](4);
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    _mainchainProposalUtils = new MainchainBridgeAdminUtils(2021, _loadGovernorPKs(), MainchainBridgeManager(_mainchainBridgeManager), governors[0]);

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: MainchainBridgeManager(_mainchainBridgeManager).round(block.chainid) + 1,
      chainId: block.chainid,
      expiryTimestamp: expiredTime,
      executor: address(0),
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });

    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](4);
    supports_[0] = Ballot.VoteType.For;
    supports_[1] = Ballot.VoteType.For;
    supports_[2] = Ballot.VoteType.For;
    supports_[3] = Ballot.VoteType.For;

    SignatureConsumer.Signature[] memory signatures = _mainchainProposalUtils.generateSignatures(proposal, _loadGovernorPKs());

    vm.broadcast(governors[0]);
    // 2_000_000 to assure tx.gasleft is bigger than the gas of the proposal.
    MainchainBridgeManager(_mainchainBridgeManager).relayProposal{gas: 2_000_000}(proposal, supports_, signatures);
  }
}
