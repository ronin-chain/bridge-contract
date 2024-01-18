// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

contract Migration__20231215_MapTokenRoninchain is BridgeMigration {
  RoninBridgeManager internal _roninBridgeManager;
  address constant _aggRoninToken = address(0x294311a8C37F0744F99EB152c419D4D3D6FEC1C7);
  address constant _aggMainchainToken = address(0xFB0489e9753B045DdB35e39c6B0Cc02EC6b99AC5);
  address internal _roninGatewayV3;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
  }

  function run() public {
    address[] memory roninTokens = new address[](1);
    roninTokens[0] = _aggRoninToken;
    address[] memory mainchainTokens = new address[](1);
    mainchainTokens[0] = _aggMainchainToken;
    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
    Token.Standard[] memory standards = new Token.Standard[](1);
    standards[0] = Token.Standard.ERC20;

    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   Token.Standard[] calldata _standards
    // )
    bytes memory innerData =
      abi.encodeCall(IRoninGatewayV3.mapTokens, (roninTokens, mainchainTokens, chainIds, standards));
    bytes memory proxyData = abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);

    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](1);
    targets[0] = _roninGatewayV3;
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = proxyData;
    uint256[] memory gasAmounts = new uint256[](1);
    gasAmounts[0] = 1_000_000;

    _verifyRoninProposalGasAmount(targets, values, calldatas, gasAmounts);

    vm.broadcast(sender());
    _roninBridgeManager.propose(block.chainid, expiredTime, targets, values, calldatas, gasAmounts);
  }
}
