// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Contract } from "../utils/Contract.sol";
import { BridgeMigration } from "../BridgeMigration.sol";
import { Network } from "../utils/Network.sol";
import { Contract } from "../utils/Contract.sol";
import { IGeneralConfigExtended } from "../IGeneralConfigExtended.sol";

contract Migration__MapTokenRoninchain is BridgeMigration {
  RoninBridgeManager internal _roninBridgeManager;

  address constant _pixelRoninToken = address(0x8b50c162494567B3c8B7F00F6031341861c8dEeD);
  // TODO: fill this address
  address constant _pixelMainchainToken = address(0x0);

  address constant _farmlandRoninToken = address(0xF083289535052E8449D69e6dc41c0aE064d8e3f6);
  // TODO: fill this address
  address constant _farmlandMainchainToken = address(0x0);

  address constant _axieChatBridgeOperator = address(0x772112C7e5dD4ed663e844e79d77c1569a2E88ce);
  address constant _axieChatGovernor = address(0x5832C3219c1dA998e828E1a2406B73dbFC02a70C);

  address internal _roninGatewayV3;

  function setUp() public override {
    super.setUp();
    _roninBridgeManager = RoninBridgeManager(_config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));
    _roninGatewayV3 = _config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key());
  }

  function _mapTokens() internal view returns (bytes memory) {
    address[] memory mainchainTokens = new address[](2);
    address[] memory roninTokens = new address[](2);
    uint256[] memory chainIds = new uint256[](2);
    Token.Standard[] memory standards = new Token.Standard[](2);

    mainchainTokens[0] = _farmlandMainchainToken;
    roninTokens[0] = _farmlandRoninToken;
    chainIds[0] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
    standards[0] = Token.Standard.ERC721;

    mainchainTokens[1] = _pixelMainchainToken;
    roninTokens[1] = _pixelRoninToken;
    chainIds[1] = _config.getCompanionNetwork(_config.getNetworkByChainId(block.chainid)).chainId();
    standards[1] = Token.Standard.ERC20;

    // function mapTokens(
    //   address[] calldata _roninTokens,
    //   address[] calldata _mainchainTokens,
    //   uint256[] calldata chainIds,
    //   Token.Standard[] calldata _standards
    // )

    bytes memory innerData = abi.encodeCall(IRoninGatewayV3.mapTokens, (
      roninTokens,
      mainchainTokens,
      chainIds,
      standards
    ));
    return abi.encodeWithSignature("functionDelegateCall(bytes)", innerData);
  }

  function _removeAxieChatGovernorAddress() pure internal returns (bytes memory) {
    address[] memory bridgeOperator = new address[](1);
    bridgeOperator[0] = _axieChatBridgeOperator;

    // function removeBridgeOperators(
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.removeBridgeOperators, (
      bridgeOperator
    ));
  }

  function _addAxieChatGovernorAddress() pure internal returns (bytes memory) {
    uint96[] memory voteWeight = new uint96[](1);
    address[] memory governor = new address[](1);
    address[] memory bridgeOperator = new address[](1);

    voteWeight[0] = 100;
    governor[0] = _axieChatGovernor;
    bridgeOperator[0] = _axieChatBridgeOperator;

    // function addBridgeOperators(
    //   uint96[] calldata voteWeights,
    //   address[] calldata governors,
    //   address[] calldata bridgeOperators
    // )

    return abi.encodeCall(IBridgeManager.addBridgeOperators, (
      voteWeight,
      governor,
      bridgeOperator
    ));
  }

  function run() public {
    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](3);
    uint256[] memory values = new uint256[](3);
    bytes[] memory calldatas = new bytes[](3);
    uint256[] memory gasAmounts = new uint256[](3);

    targets[0] = _roninGatewayV3;
    values[0] = 0;
    calldatas[0] = _mapTokens();
    gasAmounts[0] = 1_000_000;

    targets[1] = address(_roninBridgeManager);
    values[1] = 0;
    calldatas[1] = _removeAxieChatGovernorAddress();
    gasAmounts[1] = 1_000_000;

    targets[2] = address(_roninBridgeManager);
    values[2] = 0;
    calldatas[2] = _addAxieChatGovernorAddress();
    gasAmounts[2] = 1_000_000;

    _verifyRoninProposalGasAmount(targets, values, calldatas, gasAmounts);

    vm.broadcast(sender());
    _roninBridgeManager.propose(
      block.chainid,
      expiredTime,
      address(0),
      false,
      targets,
      values,
      calldatas,
      gasAmounts
    );
  }
}
