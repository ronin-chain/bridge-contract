// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Network, TNetwork } from "../../utils/Network.sol";
import { console2 as console } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Contract } from "../../utils/Contract.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import "./factory-maptoken-mainchain.s.sol";
import "../simulation/factory-maptoken-simulation-mainchain.s.sol";

abstract contract Factory__MapTokensMainchain_Sepolia is Factory__MapTokensMainchain {
  function _initGovernors() internal virtual returns (address[] memory);

  function run() public virtual override {
    super.run();
    _mainchainGatewayV3 = config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());
    _mainchainBridgeManager = config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());
    address[] memory mGovernors;
    mGovernors = _initGovernors();

    for (uint256 i; i < mGovernors.length; ++i) {
      _governors.push(mGovernors[i]);
    }

    uint256 chainId = block.chainid;
    uint256 nonce = MainchainBridgeManager(_mainchainBridgeManager).round(chainId) + 1;

    Proposal.ProposalDetail memory proposal = _createAndVerifyProposalOnMainchain(chainId, nonce);
    // Simulate relay proposal
    new Factory__MapTokensSimulation_Mainchain().simulate(proposal);
    _relayProposal(proposal);
  }
}
