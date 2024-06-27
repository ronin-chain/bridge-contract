// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract } from "../utils/Contract.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";

import { MockUSDC } from "@ronin/contracts/mocks/token/MockUSDC.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";
import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

import "../Migration.s.sol";

contract Migration__20240613_MapERC1155SepoliaRoninchain is Migration {
  RoninBridgeManager internal _roninBridgeManager;
  IRoninGatewayV3 internal _roninGatewayV3;

  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function setUp() public override {
    super.setUp();

    _roninBridgeManager = RoninBridgeManager(0x8AaAD4782890eb879A0fC132A6AdF9E5eE708faF);
    _roninGatewayV3 = IRoninGatewayV3(0xCee681C9108c42C710c6A8A949307D5F13C9F3ca);
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);
    uint256[] memory chainIds = new uint256[](1);
    uint256[][4] memory thresholds;
    thresholds[0] = new uint256[](1);
    thresholds[1] = new uint256[](1);
    thresholds[2] = new uint256[](1);
    thresholds[3] = new uint256[](1);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    mainchainTokens[0] = address(0xFBb71EEE2B420ea88e663B91722b41966E1C5F17);
    roninTokens[0] = address(0xDBB04B4BdBb385EB14cb3ea3C7B1FCcA55ea9160);
    standards[0] = TokenStandard.ERC1155;
    chainIds[0] = 11155111;

    // ================ USDC ERC-20 ======================
    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata _standards
    // )
    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = address(_roninGatewayV3);
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    address[] memory governors = new address[](4);
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    vm.broadcast(governors[0]);
    _roninBridgeManager.proposeProposalForCurrentNetwork(expiredTime, address(0), targets, values, calldatas, gasAmounts, Ballot.VoteType.For);

    uint nonce = 1;
    for (uint i = 1; i <= 2; ++i) {
      vm.broadcast(governors[i]);
      _roninBridgeManager.castProposalVoteForCurrentNetwork(Proposal.ProposalDetail({
        nonce: nonce,
        chainId: 2021,
        expiryTimestamp: expiredTime,
        executor: address(0),
        targets: targets,
        values: values,
        calldatas: calldatas,
        gasAmounts: gasAmounts
      }), Ballot.VoteType.For);
    }
  }
}
