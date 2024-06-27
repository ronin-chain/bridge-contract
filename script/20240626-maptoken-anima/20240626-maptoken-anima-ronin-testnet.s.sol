// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import "../factories/factory-maptoken-roninchain.s.sol";
import "./base-maptoken.s.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

contract Migration__20242606_MapTokenAnimaRoninTestnet is Base__MapToken, Factory__MapTokensRoninchain {
  function _initCaller() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (address) {
    return Base__MapToken._initCaller();
  }

  function _initTokenList() internal override(Base__MapToken, Factory__MapTokensRoninchain) returns (uint256 totalToken, MapTokenInfo[] memory infos) {
    return Base__MapToken._initTokenList();
  }

  function _verifyAndExecuteProposal() internal virtual override {
    // ================ VERIFY AND EXECUTE PROPOSAL ===============
    // LibProposal.verifyProposalGasAmount(address(_roninBridgeManager), targets, values, calldatas, gasAmounts);
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, uint256[] memory gasAmounts) = _prepareProposal();

    uint256 expiredTime = block.timestamp + 14 days;

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: 2,
      chainId: block.chainid,
      expiryTimestamp: expiredTime,
      executor: 0x0000000000000000000000000000000000000000,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });

    address[] memory governors = new address[](4);
    governors[3] = 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa;
    governors[2] = 0xb033ba62EC622dC54D0ABFE0254e79692147CA26;
    governors[0] = 0x087D08e3ba42e64E3948962dd1371F906D1278b9;
    governors[1] = 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F;

    // _verifyRoninProposalGasAmount(targets, values, calldatas, gasAmounts);

    vm.broadcast(governors[0]);
    _roninBridgeManager.propose(block.chainid, expiredTime, address(0), targets, values, calldatas, gasAmounts);
    vm.broadcast(governors[0]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    vm.broadcast(governors[1]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
    vm.broadcast(governors[2]);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, Ballot.VoteType.For);
  }

  function run() public override {
    console2.log("nonce", vm.getNonce(SM_GOVERNOR)); // Log nonce for workaround of nonce increase when switch network
    super.run();
  }
}
