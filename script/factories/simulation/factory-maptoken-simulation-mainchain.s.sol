// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ronin/contracts/libraries/Ballot.sol";
import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import "@ronin/contracts/libraries/Ballot.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import "./factory-maptoken-simulation-base.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { Contract } from "../../utils/Contract.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Network, TNetwork } from "../../utils/Network.sol";

contract Factory__MapTokensSimulation_Mainchain is Factory__MapTokensSimulation_Base {
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _mainchainGatewayV3;
  address internal _mainchainBridgeManager;

  function _setUp() internal override {
    if (network() == DefaultNetwork.RoninMainnet.key() || network() == DefaultNetwork.RoninTestnet.key()) {
      _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
      _mainchainGatewayV3 = config.getAddress(network().companionNetwork(), Contract.MainchainGatewayV3.key());
      _mainchainBridgeManager = config.getAddress(network().companionNetwork(), Contract.MainchainBridgeManager.key());
    } else {
      _mainchainGatewayV3 = config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key());
      _mainchainBridgeManager = config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());
    }
  }

  function simulate(Proposal.ProposalDetail memory proposal) public inSimulation {
    super.simulate();

    Ballot.VoteType[] memory cheatingSupports = new Ballot.VoteType[](1);
    uint256[] memory cheatingPks = new uint256[](1);
    (address cheatingGov, uint256 cheatingGovPk) = makeAddrAndKey("Governor");

    cheatingSupports[0] = Ballot.VoteType.For;
    cheatingPks[0] = cheatingGovPk;
    SignatureConsumer.Signature[] memory cheatingSignatures = LibProposal.generateSignatures(proposal, cheatingPks, Ballot.VoteType.For);

    uint256 gasAmounts = 1_000_000;
    for (uint256 i; i < proposal.gasAmounts.length; ++i) {
      gasAmounts += proposal.gasAmounts[i];
    }

    vm.startPrank(cheatingGov);
    if (network() == DefaultNetwork.RoninMainnet.key() || network() == DefaultNetwork.RoninTestnet.key()) {
      _cheatWeightOperator(IBridgeManager(_roninBridgeManager), cheatingGov);

      _roninBridgeManager.propose(
        proposal.chainId, proposal.expiryTimestamp, proposal.executor, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts
      );
      _roninBridgeManager.castProposalBySignatures(proposal, cheatingSupports, cheatingSignatures);

      address mMainchainAdress = _mainchainBridgeManager;
      TNetwork currentNetwork = network();
      config.createFork(network().companionNetwork());
      config.switchTo(network().companionNetwork());

      // Handle wrong nonce on testnet
      if (currentNetwork == DefaultNetwork.RoninTestnet.key()) {
        uint256 roundSlot = 2;
        bytes32 $ = keccak256(abi.encode(block.chainid, roundSlot));

        bytes32 newNonce = bytes32(proposal.nonce - 1);
        vm.store(address(mMainchainAdress), $, newNonce);
        assertEq(MainchainBridgeManager(mMainchainAdress).round(block.chainid) + 1, proposal.nonce);
      }

      _cheatWeightOperator(IBridgeManager(mMainchainAdress), cheatingGov);
      MainchainBridgeManager(mMainchainAdress).relayProposal{ gas: gasAmounts }(proposal, cheatingSupports, cheatingSignatures);

      config.switchTo(currentNetwork);
    } else {
      _cheatWeightOperator(IBridgeManager(_mainchainBridgeManager), cheatingGov);
      MainchainBridgeManager(_mainchainBridgeManager).relayProposal{ gas: gasAmounts }(proposal, cheatingSupports, cheatingSignatures);
    }
    vm.stopPrank();
  }
}
