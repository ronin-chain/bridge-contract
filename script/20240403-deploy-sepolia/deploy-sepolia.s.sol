// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISharedArgument } from "@ronin/script/interfaces/ISharedArgument.sol";
import { LibSharedAddress } from "foundry-deployment-kit/libraries/LibSharedAddress.sol";

import "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import "@ronin/contracts/ronin/gateway/PauseEnforcer.sol";
import "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MockERC20 } from "@ronin/contracts/mocks/token/MockERC20.sol";
import { MockERC721 } from "@ronin/contracts/mocks/token/MockERC721.sol";
import { MockWrappedToken } from "@ronin/contracts/mocks/token/MockWrappedToken.sol";

import { MainchainBridgeAdminUtils } from "test/helpers/MainchainBridgeAdminUtils.t.sol";

import { MainchainGatewayV3Deploy } from "@ronin/script/contracts/MainchainGatewayV3Deploy.s.sol";
import { MainchainBridgeManagerDeploy } from "@ronin/script/contracts/MainchainBridgeManagerDeploy.s.sol";
import { MainchainPauseEnforcerDeploy } from "@ronin/script/contracts/MainchainPauseEnforcerDeploy.s.sol";
import { WETHDeploy } from "@ronin/script/contracts/token/WETHDeploy.s.sol";
import { WRONDeploy } from "@ronin/script/contracts/token/WRONDeploy.s.sol";
import { AXSDeploy } from "@ronin/script/contracts/token/AXSDeploy.s.sol";
import { SLPDeploy } from "@ronin/script/contracts/token/SLPDeploy.s.sol";
import { USDCDeploy } from "@ronin/script/contracts/token/USDCDeploy.s.sol";
import { MockERC721Deploy } from "@ronin/script/contracts/token/MockERC721Deploy.s.sol";

import { GeneralConfig } from "../GeneralConfig.sol";
import { Network } from "../utils/Network.sol";
import { BridgeMigration } from "../BridgeMigration.sol";

import "./changeGV-config.s.sol";

import "forge-std/console2.sol";

contract DeploySepolia is BridgeMigration, DeploySepolia__ChangeGV_Config {
  ISharedArgument.SharedParameter _param;

  PauseEnforcer _mainchainPauseEnforcer;
  MainchainGatewayV3 _mainchainGatewayV3;
  MainchainBridgeManager _mainchainBridgeManager;

  MockWrappedToken _mainchainWeth;
  MockERC20 _mainchainAxs;
  MockERC20 _mainchainUsdc;
  MockERC721 _mainchainMockERC721;

  MainchainBridgeAdminUtils _mainchainProposalUtils;

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    return "";
  }

  function setUp() public override {
    super.setUp();
  }

  function run() public onlyOn(Network.Sepolia.key()) {
    _deployContractsOnMainchain();
    _mainchainGatewayV3Initialize();
    _correctGVs();
  }

  function _deployContractsOnMainchain() internal {
    _mainchainPauseEnforcer = new MainchainPauseEnforcerDeploy().run();
    _mainchainGatewayV3 = new MainchainGatewayV3Deploy().run();
    _mainchainBridgeManager = new MainchainBridgeManagerDeploy().run();

    _mainchainWeth = new WETHDeploy().run();
    _mainchainAxs = new AXSDeploy().run();
    _mainchainUsdc = new USDCDeploy().run();
    _mainchainMockERC721 = new MockERC721Deploy().run();

    _param = ISharedArgument(LibSharedAddress.CONFIG).sharedArguments();
    _mainchainProposalUtils = new MainchainBridgeAdminUtils(
      2021, _param.test.governorPKs, _mainchainBridgeManager, _param.mainchainBridgeManager.governors[0]
    );
  }

  function _mainchainGatewayV3Initialize() internal {
    (address[] memory mainchainTokens, address[] memory roninTokens) = _getMainchainAndRoninTokens();
    uint256 tokenNum = mainchainTokens.length;
    uint256[] memory highTierThreshold = new uint256[](tokenNum);
    uint256[] memory lockedThreshold = new uint256[](tokenNum);
    uint256[] memory unlockFeePercentages = new uint256[](tokenNum);
    uint256[] memory dailyWithdrawalLimits = new uint256[](tokenNum);
    Token.Standard[] memory standards = new Token.Standard[](tokenNum);

    for (uint256 i; i < tokenNum; i++) {
      bool isERC721 = i == mainchainTokens.length - 1; // last item is ERC721

      highTierThreshold[i] = 10;
      lockedThreshold[i] = 20;
      unlockFeePercentages[i] = 100_000;
      dailyWithdrawalLimits[i] = 12;
      standards[i] = isERC721 ? Token.Standard.ERC721 : Token.Standard.ERC20;
    }

    // Mainchain Gateway V3
    _param.mainchainGatewayV3.wrappedToken = address(_mainchainWeth);
    _param.mainchainGatewayV3.addresses[0] = mainchainTokens; // (ERC20 + ERC721)
    _param.mainchainGatewayV3.addresses[1] = roninTokens; // (ERC20 + ERC721)
    _param.mainchainGatewayV3.addresses[2] = new address[](0);
    _param.mainchainGatewayV3.thresholds[0] = highTierThreshold;
    _param.mainchainGatewayV3.thresholds[1] = lockedThreshold;
    _param.mainchainGatewayV3.thresholds[2] = unlockFeePercentages;
    _param.mainchainGatewayV3.thresholds[3] = dailyWithdrawalLimits;
    _param.mainchainGatewayV3.standards = standards;

    ISharedArgument.MainchainGatewayV3Param memory param = _param.mainchainGatewayV3;

    vm.broadcast(sender());
    _mainchainGatewayV3.initialize(
      param.roleSetter,
      IWETH(param.wrappedToken),
      2021,
      param.numerator,
      param.highTierVWNumerator,
      param.denominator,
      param.addresses,
      param.thresholds,
      param.standards
    );

    vm.broadcast(sender());
    _mainchainGatewayV3.initializeV2(address(_mainchainBridgeManager));
  }

  function _correctGVs() internal {
    uint256 expiredTime = block.timestamp + 10 days;
    address[] memory targets = new address[](2);
    uint256[] memory values = new uint256[](2);
    bytes[] memory calldatas = new bytes[](2);
    uint256[] memory gasAmounts = new uint256[](2);

    targets[0] = address(_mainchainBridgeManager);
    values[0] = 0;
    calldatas[0] = _removeInitOperator();
    gasAmounts[0] = 1_000_000;

    targets[1] = address(_mainchainBridgeManager);
    values[1] = 0;
    calldatas[1] = _addTestnetOperators();
    gasAmounts[1] = 1_000_000;

    // ================ VERIFY AND EXECUTE PROPOSAL ===============

    // _verifyMainchainProposalGasAmount(targets, values, calldatas, gasAmounts);

    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: _mainchainBridgeManager.round(0) + 1,
      chainId: block.chainid,
      expiryTimestamp: expiredTime,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts
    });

    Ballot.VoteType[] memory supports_ = new Ballot.VoteType[](1);
    supports_[0] = Ballot.VoteType.For;

    SignatureConsumer.Signature[] memory signatures =
      _mainchainProposalUtils.generateSignatures(proposal, _param.test.governorPKs);

    vm.broadcast(_mainchainBridgeManager.getGovernors()[0]);
    _mainchainBridgeManager.relayProposal(proposal, supports_, signatures);
  }

  function _getMainchainAndRoninTokens()
    internal
    view
    returns (address[] memory mainchainTokens, address[] memory roninTokens)
  {
    uint256 tokenNum = 5;
    mainchainTokens = new address[](tokenNum);
    roninTokens = new address[](tokenNum);

    mainchainTokens[0] = address(_mainchainWeth);
    mainchainTokens[1] = address(_mainchainAxs);
    mainchainTokens[2] = address(_mainchainUsdc);
    mainchainTokens[3] = address(_mainchainMockERC721);

    roninTokens[0] = address(0x00);
    roninTokens[1] = address(0x00);
    roninTokens[2] = address(0x067FBFf8990c58Ab90BaE3c97241C5d736053F77);
    roninTokens[3] = address(0x00);
  }
}
