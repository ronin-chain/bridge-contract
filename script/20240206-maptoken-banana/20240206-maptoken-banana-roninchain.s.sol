// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { MinimumWithdrawal } from "@ronin/contracts/extensions/MinimumWithdrawal.sol";
import { LibTokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { GlobalProposal } from "@ronin/contracts/libraries/GlobalProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import { Migration } from "../Migration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { TNetwork, Network } from "../utils/Network.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibCompanionNetwork } from "script/shared/libraries/LibCompanionNetwork.sol";

import "./maptoken-banana-configs.s.sol";
import "./maptoken-genkai-configs.s.sol";
import "./maptoken-vx-configs.s.sol";
import "./changeGV-stablenode-config.s.sol";

contract Migration__20240206_MapTokenBananaRoninChain is
  Migration,
  Migration__MapToken_Banana_Config,
  Migration__MapToken_Vx_Config,
  Migration__MapToken_Genkai_Config,
  Migration__ChangeGV_StableNode_Config
{
  using LibProposal for *;
  using LibCompanionNetwork for *;

  RoninBridgeManager internal _roninBridgeManager;
  address internal _roninGatewayV3;

  address pixelRoninToken = 0x7EAe20d11Ef8c779433Eb24503dEf900b9d28ad7;
  address pixelMainchainToken = 0x3429d03c6F7521AeC737a0BBF2E5ddcef2C3Ae31;
  uint256 pixelMinThreshold = 10 ether;

  address aggRoninToken = 0x294311a8C37F0744F99EB152c419D4D3D6FEC1C7;
  address aggMainchainToken = 0xFB0489e9753B045DdB35e39c6B0Cc02EC6b99AC5;
  uint256 aggMinThreshold = 1000 ether;

  function setUp() public virtual override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
  }

  function _cheatWeightOperator(address gov) internal {
    bytes32 $ = keccak256(abi.encode(gov, 0x88547008e60f5748911f2e59feb3093b7e4c2e87b2dd69d61f112fcc932de8e3));
    bytes32 opAndWeight = vm.load(address(_roninBridgeManager), $);

    uint256 totalWeight = _roninBridgeManager.getTotalWeight();
    bytes32 newOpAndWeight = bytes32((totalWeight << 160) + uint160(uint256(opAndWeight)));
    vm.store(address(_roninBridgeManager), $, newOpAndWeight);
  }

  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
    address[] memory roninTokens = new address[](3);
    address[] memory mainchainTokens = new address[](3);
    uint256[] memory chainIds = new uint256[](3);
    TokenStandard[] memory standards = new TokenStandard[](3);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory calldatas = new bytes[](4);
    uint256[] memory gasAmounts = new uint256[](4);

    // ============= MAP NEW BANANA, VX, GENKAI TOKEN  ===========

    uint256 companionChainId = network().companionChainId();
    roninTokens[0] = _bananaRoninToken;
    mainchainTokens[0] = _bananaMainchainToken;
    chainIds[0] = companionChainId;
    standards[0] = TokenStandard.ERC20;

    roninTokens[1] = _VxRoninToken;
    mainchainTokens[1] = _VxMainchainToken;
    chainIds[1] = companionChainId;
    standards[1] = TokenStandard.ERC721;

    roninTokens[2] = _genkaiRoninToken;
    mainchainTokens[2] = _genkaiMainchainToken;
    chainIds[2] = companionChainId;
    standards[2] = TokenStandard.ERC721;

    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   TokenStandard[] calldata _standards
    // )
    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = proxyData;
    gasAmounts[0] = 1_000_000;

    // ============= SET MIN THRESHOLD FOR BANANA, PIXEL, AGG ============
    // function setMinimumThresholds(
    //   address[] calldata _tokens,
    //   uint256[] calldata _thresholds
    // );
    address[] memory roninTokensToSetMinThreshold = new address[](5);
    uint256[] memory minThresholds = new uint256[](5);

    roninTokensToSetMinThreshold[0] = _bananaRoninToken;
    minThresholds[0] = _bananaMinThreshold;

    roninTokensToSetMinThreshold[1] = pixelRoninToken;
    minThresholds[1] = pixelMinThreshold;

    roninTokensToSetMinThreshold[2] = pixelMainchainToken;
    minThresholds[2] = 0;

    roninTokensToSetMinThreshold[3] = aggRoninToken;
    minThresholds[3] = aggMinThreshold;

    roninTokensToSetMinThreshold[4] = aggMainchainToken;
    minThresholds[4] = 0;

    innerData = abi.encodeCall(MinimumWithdrawal.setMinimumThresholds, (roninTokensToSetMinThreshold, minThresholds));
    proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    targets[1] = _roninGatewayV3;
    values[1] = 0;
    calldatas[1] = proxyData;
    gasAmounts[1] = 1_000_000;

    // =============== AXIE CHAT UPDATE ===========
    targets[2] = address(_roninBridgeManager);
    values[2] = 0;
    calldatas[2] = _removeStableNodeGovernorAddress();
    gasAmounts[2] = 1_000_000;

    targets[3] = address(_roninBridgeManager);
    values[3] = 0;
    calldatas[3] = _addStableNodeGovernorAddress();
    gasAmounts[3] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    TNetwork currentNetwork = network();
    TNetwork companionNetwork = config.getCompanionNetwork(currentNetwork);
    config.createFork(companionNetwork);
    config.switchTo(companionNetwork);
    {
      address companionManager = config.getAddress(companionNetwork, Contract.MainchainBridgeManager.key());
      LibProposal.verifyProposalGasAmount(companionManager, targets, values, calldatas, gasAmounts);
    }
    config.switchTo(currentNetwork);

    console2.log("Nonce:", vm.getNonce(_governor));
    vm.broadcast(_governor);
    _roninBridgeManager.propose(block.chainid, expiredTime, address(0), targets, values, calldatas, gasAmounts);

    // ============= LOCAL SIMULATION ==================
    _cheatWeightOperator(_governor);

    Proposal.ProposalDetail memory cheatingProposal;
    cheatingProposal.nonce = 3;
    cheatingProposal.chainId = block.chainid;
    cheatingProposal.expiryTimestamp = expiredTime;
    cheatingProposal.targets = targets;
    cheatingProposal.values = values;
    cheatingProposal.calldatas = calldatas;
    cheatingProposal.gasAmounts = gasAmounts;

    Ballot.VoteType cheatingSupport = Ballot.VoteType.For;

    vm.prank(_governor);
    _roninBridgeManager.castProposalVoteForCurrentNetwork(cheatingProposal, cheatingSupport);
  }
}

// ./run.sh script/20240206-maptoken-banana/20240206-maptoken-banana-roninchain.s.sol -f ronin-mainnet --fork-block-number 31791206 -vvvv
