// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import "./factory-maptoken-simulation-base.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Contract } from "../../utils/Contract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

contract Factory__MapTokensSimulation_Roninchain is Factory__MapTokensSimulation_Base {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;

  function _setUp() internal override {
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
  }

  function simulate(Proposal.ProposalDetail memory proposal) public inSimulation {
    super.simulate();

    Ballot.VoteType cheatingSupport = Ballot.VoteType.For;
    address cheatingGov = makeAddr("Governor");
    _cheatWeightOperator(IBridgeManager(_roninBridgeManager), cheatingGov);

    vm.startPrank(cheatingGov);
    _roninBridgeManager.propose(
      proposal.chainId, proposal.expiryTimestamp, proposal.executor, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts
    );
    _roninBridgeManager.castProposalVoteForCurrentNetwork(proposal, cheatingSupport);
    vm.stopPrank();

    if (proposal.executor != address(0)) {
      vm.prank(proposal.executor);
      _roninBridgeManager.execute(proposal);
    }
  }
}
