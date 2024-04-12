// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { LibString } from "solady/utils/LibString.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { GeneralConfig } from "./GeneralConfig.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { TNetwork, Network } from "./utils/Network.sol";
import { Utils } from "./utils/Utils.sol";
import { LibTokenInfo, TokenInfo, TokenStandard } from "@ronin/contracts/libraries/LibTokenInfo.sol";
import { Contract, TContract } from "./utils/Contract.sol";
import { GlobalProposal, Proposal, LibProposal } from "script/shared/libraries/LibProposal.sol";
import { TransparentUpgradeableProxy, TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { LibArray } from "script/shared/libraries/LibArray.sol";
import { PostChecker } from "./PostChecker.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";

contract Migration is PostChecker, Utils {
  using LibProxy for *;
  using LibArray for *;
  using StdStyle for *;
  using LibString for *;
  using LibProposal for *;

  uint256 internal constant DEFAULT_PROPOSAL_GAS = 1_000_000;
  ISharedArgument internal constant config = ISharedArgument(address(CONFIG));

  bool internal _isLocalETH;

  function setUp() public virtual override {
    super.setUp();
  }

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == Network.Sepolia.key()) {
      // tokens
      param.weth.name = "Wrapped WETH";
      param.weth.symbol = "WETH";
      param.axs.name = "Axie Infinity Shard";
      param.axs.symbol = "AXS";
      param.usdc.name = "USD Coin";
      param.usdc.symbol = "USDC";
      param.mockErc721.name = "Mock ERC721";
      param.mockErc721.symbol = "M_ERC721";

      uint256 num = 1;
      address[] memory operatorAddrs = new address[](num);
      address[] memory governorAddrs = new address[](num);
      uint256[] memory operatorPKs = new uint256[](num);
      uint256[] memory governorPKs = new uint256[](num);
      uint96[] memory voteWeights = new uint96[](num);
      GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](0);
      address[] memory targets = new address[](0);

      operatorAddrs[0] = 0xbA8E32D874948dF4Cbe72284De91CC4968293BCe; // One-time address, becomes useless after this migration
      operatorPKs[0] = 0xd5df10f17539ff887f211a90bfede2dffb664b7442b4303ba93ac8f6a7d9fa9b; // One-time address, becomes useless after this migration

      governorAddrs[0] = 0x45E8f1aCFC89F45720cf11e807eD85B730C67C7e; // One-time address, becomes useless after this migration
      governorPKs[0] = 0xc2b5a7cc553931272fc819150c4ea31d24ad06fdfa021c403b2ef5293bfe685b; // One-time address, becomes useless after this migration
      voteWeights[0] = 100;

      param.test.operatorPKs = operatorPKs;
      param.test.governorPKs = governorPKs;

      // Mainchain Gateway Pause Enforcer
      param.mainchainPauseEnforcer.admin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
      param.mainchainPauseEnforcer.sentries = wrapAddress(0x8Ed0c5B427688f2Bd945509199CAa4741C81aFFe); // Gnosis Sepolia

      // Mainchain Gateway V3
      param.mainchainGatewayV3.roleSetter = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
      param.mainchainGatewayV3.roninChainId = 2021;
      param.mainchainGatewayV3.numerator = 4;
      param.mainchainGatewayV3.highTierVWNumerator = 7;
      param.mainchainGatewayV3.denominator = 10;

      // Mainchain Bridge Manager
      param.mainchainBridgeManager.num = 2;
      param.mainchainBridgeManager.denom = 4;
      param.mainchainBridgeManager.roninChainId = 2021;
      param.mainchainBridgeManager.bridgeOperators = operatorAddrs;
      param.mainchainBridgeManager.governors = governorAddrs;
      param.mainchainBridgeManager.voteWeights = voteWeights;
      param.mainchainBridgeManager.targetOptions = options;
      param.mainchainBridgeManager.targets = targets;
    } else if (network() == DefaultNetwork.RoninTestnet.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.RoninMainnet.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.Local.key()) {
      // test
      param.test.numberOfBlocksInEpoch = 200;
      param.test.proxyAdmin = makeAddr("proxy-admin");
      param.test.dposGA = makeAddr("governance-admin");

      // tokens
      param.weth.name = "Wrapped WETH";
      param.weth.symbol = "WETH";
      param.wron.name = "Wrapped RON";
      param.wron.symbol = "WRON";
      param.axs.name = "Axie Infinity Shard";
      param.axs.symbol = "AXS";
      param.slp.name = "Smooth Love Potion";
      param.slp.symbol = "SLP";
      param.usdc.name = "USD Coin";
      param.usdc.symbol = "USDC";
      param.mockErc721.name = "Mock ERC721";
      param.mockErc721.symbol = "M_ERC721";
      param.mockErc1155.uri = "mock://erc1155/";

      uint256 num = 6;
      address[] memory operatorAddrs = new address[](num);
      address[] memory governorAddrs = new address[](num);
      uint256[] memory operatorPKs = new uint256[](num);
      uint256[] memory governorPKs = new uint256[](num);
      uint96[] memory voteWeights = new uint96[](num);
      GlobalProposal.TargetOption[] memory options = new GlobalProposal.TargetOption[](0);
      address[] memory targets = new address[](0);

      for (uint256 i; i < num; i++) {
        (address addrOperator, uint256 pkOperator) = makeAddrAndKey(string.concat("operator-", vm.toString(i + 1)));
        (address addrGovernor, uint256 pkGovernor) = makeAddrAndKey(string.concat("governor-", vm.toString(i + 1)));

        operatorAddrs[i] = addrOperator;
        governorAddrs[i] = addrGovernor;
        operatorPKs[i] = pkOperator;
        governorPKs[i] = pkGovernor;
        voteWeights[i] = 100;
      }

      operatorPKs.inplaceSortByValue(operatorAddrs.toUint256s());
      governorPKs.inplaceSortByValue(governorAddrs.toUint256s());

      param.test.operatorPKs = operatorPKs;
      param.test.governorPKs = governorPKs;

      // Bridge rewards
      param.bridgeReward.dposGA = param.test.dposGA;
      param.bridgeReward.rewardPerPeriod = 5_000;

      // Bridge Slash
      param.bridgeSlash.dposGA = param.test.dposGA;

      // Bridge Tracking

      // Ronin Gateway Pause Enforcer
      param.roninPauseEnforcer.admin = makeAddr("pause-enforcer-admin");
      param.roninPauseEnforcer.sentries = wrapAddress(makeAddr("pause-enforcer-sentry"));

      // Ronin Gateway V3
      param.roninGatewayV3.numerator = 3;
      param.roninGatewayV3.denominator = 6;
      param.roninGatewayV3.trustedNumerator = 2;
      param.roninGatewayV3.trustedDenominator = 3;

      // Ronin Bridge Manager
      param.roninBridgeManager.num = 2;
      param.roninBridgeManager.denom = 4;
      param.roninBridgeManager.roninChainId = 0;
      param.roninBridgeManager.roninChainId = block.chainid;
      param.roninBridgeManager.expiryDuration = 14 days;
      param.roninBridgeManager.bridgeOperators = operatorAddrs;
      param.roninBridgeManager.governors = governorAddrs;
      param.roninBridgeManager.voteWeights = voteWeights;
      param.roninBridgeManager.targetOptions = options;
      param.roninBridgeManager.targets = targets;

      // Mainchain Gateway Pause Enforcer
      param.mainchainPauseEnforcer.admin = makeAddr("pause-enforcer-admin");
      param.mainchainPauseEnforcer.sentries = wrapAddress(makeAddr("pause-enforcer-sentry"));

      // Mainchain Gateway V3
      param.mainchainGatewayV3.roninChainId = block.chainid;
      param.mainchainGatewayV3.numerator = 1;
      param.mainchainGatewayV3.highTierVWNumerator = 10;
      param.mainchainGatewayV3.denominator = 10;

      // Mainchain Bridge Manager
      param.mainchainBridgeManager.num = 2;
      param.mainchainBridgeManager.denom = 4;
      param.mainchainBridgeManager.roninChainId = 0;
      param.mainchainBridgeManager.roninChainId = block.chainid;
      param.mainchainBridgeManager.bridgeOperators = operatorAddrs;
      param.mainchainBridgeManager.governors = governorAddrs;
      param.mainchainBridgeManager.voteWeights = voteWeights;
      param.mainchainBridgeManager.targetOptions = options;
      param.mainchainBridgeManager.targets = targets;
    } else {
      revert("Migration: Network Unknown Shared Parameters Unimplemented!");
    }

    rawArgs = abi.encode(param);
  }

  function _getProxyAdmin() internal virtual override returns (address payable proxyAdmin) {
    TNetwork currentNetwork = network();
    if (
      currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key() || currentNetwork == Network.RoninDevnet.key()
    ) {
      proxyAdmin = loadContract(Contract.RoninBridgeManager.key());
    } else if (currentNetwork == Network.Sepolia.key() || currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
      proxyAdmin = loadContract(Contract.MainchainBridgeManager.key());
    } else if (currentNetwork == DefaultNetwork.Local.key()) {
      TContract managerContractType = _isLocalETH ? Contract.MainchainBridgeManager.key() : Contract.RoninBridgeManager.key();
      try config.getAddressFromCurrentNetwork(managerContractType) returns (address payable addr) {
        proxyAdmin = addr;
      } catch {
        proxyAdmin = payable(config.sharedArguments().test.proxyAdmin);
      }
    } else {
      console.log("Network not supported".yellow(), currentNetwork.networkName());
      console.log("Chain Id".yellow(), block.chainid);
      revert("BridgeMigration(_getProxyAdmin): Unhandled case");
    }
  }

  function _upgradeRaw(address proxyAdmin, address payable proxy, address logic, bytes memory args) internal virtual override {
    if (!config.isPostChecking() && logic.codehash == payable(proxy).getProxyImplementation({ nullCheck: true }).codehash) {
      console.log("BaseMigration: Logic is already upgraded!".yellow());
      return;
    }

    assertTrue(proxyAdmin != address(0x0), "BridgeMigration: Invalid {proxyAdmin} or {proxy} is not a Proxy contract");
    address admin = _getProxyAdmin();
    TNetwork currentNetwork = network();

    if (proxyAdmin == admin) {
      // in case proxyAdmin is GovernanceAdmin
      if (
        currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key()
          || currentNetwork == Network.RoninDevnet.key() || currentNetwork == DefaultNetwork.Local.key()
      ) {
        // handle for ronin network
        console.log(StdStyle.yellow("Voting on RoninBridgeManager for upgrading..."));

        RoninBridgeManager manager = RoninBridgeManager(admin);
        bytes[] memory callDatas = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        address[] memory targets = new address[](1);

        targets[0] = proxy;
        callDatas[0] = args.length == 0
          ? abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logic))
          : abi.encodeCall(TransparentUpgradeableProxy.upgradeToAndCall, (logic, args));

        Proposal.ProposalDetail memory proposal = LibProposal.createProposal({
          manager: address(manager),
          nonce: manager.round(block.chainid) + 1,
          expiryTimestamp: block.timestamp + 10 minutes,
          targets: targets,
          values: values,
          calldatas: callDatas,
          gasAmounts: uint256(DEFAULT_PROPOSAL_GAS).toSingletonArray()
        });

        manager.executeProposal(proposal);
        assertEq(proxy.getProxyImplementation(), logic, "BridgeMigration: Upgrade failed");
      } else if (currentNetwork == Network.Sepolia.key() || currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
        // handle for ethereum
        revert("BridgeMigration: Unhandled case for ETH");
      } else {
        revert("BridgeMigration: Unhandled case");
      }
    } else if (proxyAdmin.code.length == 0) {
      // in case proxyAdmin is an eoa
      console.log(StdStyle.yellow("Upgrading with EOA wallet..."));
      _prankOrBroadcast(address(proxyAdmin));
      if (args.length == 0) TransparentUpgradeableProxyV2(proxy).upgradeTo(logic);
      else TransparentUpgradeableProxyV2(proxy).upgradeToAndCall(logic, args);
    } else {
      console.log(StdStyle.yellow("Upgrading with owner of ProxyAdmin contract..."));
      // in case proxyAdmin is a ProxyAdmin contract
      ProxyAdmin proxyAdminContract = ProxyAdmin(proxyAdmin);
      address authorizedWallet = proxyAdminContract.owner();
      _prankOrBroadcast(authorizedWallet);
      if (args.length == 0) proxyAdminContract.upgrade(TransparentUpgradeableProxy(proxy), logic);
      else proxyAdminContract.upgradeAndCall(TransparentUpgradeableProxy(proxy), logic, args);
    }
  }

  function _deployLogic(TContract contractType) internal virtual override returns (address payable logic) {
    logic = _deployLogic(contractType, EMPTY_ARGS);
  }

  function _deployProxy(
    TContract contractType,
    bytes memory args
  ) internal virtual override logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne())) returns (address payable deployed) {
    string memory contractName = config.getContractName(contractType);

    address logic = _deployLogic(contractType);
    string memory proxyAbsolutePath = "TransparentUpgradeableProxyV2.sol:TransparentUpgradeableProxyV2";
    uint256 proxyNonce;
    address proxyAdmin = _getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    (deployed, proxyNonce) = _deployRaw(proxyAbsolutePath, abi.encode(logic, proxyAdmin, args));

    // validate proxy admin
    address actualProxyAdmin = deployed.getProxyAdmin();
    assertEq(
      actualProxyAdmin,
      proxyAdmin,
      string.concat("BaseMigration: Invalid proxy admin\n", "Actual: ", vm.toString(actualProxyAdmin), "\nExpected: ", vm.toString(proxyAdmin))
    );

    config.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce);
  }

  function _getProxyAdminFromCurrentNetwork() internal view virtual returns (address proxyAdmin) {
    TNetwork currentNetwork = network();
    if (currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key()) {
      proxyAdmin = config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());
    } else if (currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
      proxyAdmin = config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());
    } else {
      revert("BridgeMigration(_getProxyAdminFromCurrentNetwork): Unhandled case");
    }
  }
}
