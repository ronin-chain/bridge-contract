// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { Network, TNetwork } from "../../utils/Network.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Contract } from "../../utils/Contract.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "./factory-maptoken-mainchain.s.sol";
import "../simulation/factory-maptoken-simulation-mainchain.s.sol";

abstract contract Factory__MapTokensMainchain_Ethereum is Factory__MapTokensMainchain {
  using LibCompanionNetwork for *;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _mainchainGatewayV3 = config.getAddress(network().companionNetwork(), Contract.MainchainGatewayV3.key());
    _mainchainBridgeManager = config.getAddress(network().companionNetwork(), Contract.MainchainBridgeManager.key());
  }

  function run() public virtual override {
    uint256 chainId = network().companionChainId();
    uint256 nonce = _roninBridgeManager.round(chainId) + 1;
    Proposal.ProposalDetail memory proposal = _createAndVerifyProposalOnMainchain(chainId, nonce);
    // Simulate relay proposal
    new Factory__MapTokensSimulation_Mainchain().simulate(proposal);
    _propose(proposal);
  }
}
