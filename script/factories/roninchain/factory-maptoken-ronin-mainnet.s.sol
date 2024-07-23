pragma solidity ^0.8.19;

import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Network, TNetwork } from "../../utils/Network.sol";
import { console2 } from "forge-std/console2.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Contract } from "../../utils/Contract.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "./factory-maptoken-roninchain.s.sol";
import "../simulation/factory-maptoken-simulation-roninchain.s.sol";

abstract contract Factory__MapTokensRonin_Mainnet is Factory__MapTokensRoninchain {
  using LibCompanionNetwork for *;

  function run() public virtual override {
    Proposal.ProposalDetail memory proposal = _createAndVerifyProposalOnRonin();
    // Simulate execute proposal
    new Factory__MapTokensSimulation_Roninchain().simulate(proposal);
    _propose(proposal);
  }
}
