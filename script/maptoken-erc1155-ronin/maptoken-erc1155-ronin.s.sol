// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninBridgeAdminUtils } from "../../test/helpers/RoninBridgeAdminUtils.t.sol";
import "@ronin/contracts/interfaces/IRoninGateWayv3.sol";
import "../Migration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

contract Migration__MapERC1155Ronin is Migration {
  address internal _roninGatewayV3;
  RoninBridgeManager internal _roninBridgeManager;

  RoninBridgeAdminUtils _roninProposalUtils;

  function setUp() public override {
    super.setUp();

    _roninGatewayV3 = loadContract(Contract.RoninGatewayV3.key());
    _roninBridgeManager = RoninBridgeManager(loadContract(Contract.RoninBridgeManager.key()));
  }

  function run() public {
    address[] memory mainchainTokens = new address[](1);
    address[] memory roninTokens = new address[](1);
    uint256[] memory chainIds = new uint256[](1);
    TokenStandard[] memory standards = new TokenStandard[](1);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory gasAmounts = new uint256[](1);

    address[] memory governors = new address[](4);
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    // ================ Mock ERC-1155 ======================
    mainchainTokens[0] = address(0x25A9beea337cC48fca4D8848Ef3Ae1b5F28eB0ab);
    roninTokens[0] = address(0x00e2b6f0b196b411c8e0eef355a920d4d3221ab968);
    chainIds[0] = config.getNetworkData(config.getCompanionNetwork(network())).chainId;
    standards[0] = TokenStandard.ERC1155;

    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    LibProposal.verifyProposalGasAmount(address(_roninBridgeManager), targets, values, calldatas, gasAmounts);

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: 2,
      chainId: 2021,
      expiryTimestamp: expiredTime,
      executor: 0x0000000000000000000000000000000000000000,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });

    vm.broadcast(governors[1]);
    _roninBridgeManager.propose(block.chainid, expiredTime, address(0), targets, values, calldatas, gasAmounts);
    vm.broadcast(governors[0]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    vm.broadcast(governors[1]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    vm.broadcast(governors[2]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
  }
}
