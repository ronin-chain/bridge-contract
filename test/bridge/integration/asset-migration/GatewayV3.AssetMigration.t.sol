// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BaseIntegration.t.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { MockCCIPPoolSingleLane } from "test/mocks/MockCCIPPoolSingleLane.sol";
import { MockCCIPPoolMultiLane } from "test/mocks/MockCCIPPoolMultiLane.sol";

contract GatewayV3_AssetMigration is BaseIntegration_Test {
  address internal _pauseEnforcer;
  address internal _migrator;

  address[] internal _ronTokens;
  address[] internal _ronRecipients;
  uint64[] internal _ronRemoteChainSelectors;

  address[] internal _ethTokens;
  address[] internal _ethRecipients;
  uint64[] internal _ethRemoteChainSelectors;

  bytes32 internal constant _MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  function setUp() public virtual override {
    super.setUp();

    _pauseEnforcer = makeAddr("pause-enforcer");
    _migrator = makeAddr("migrator");

    _initialize();
  }

  function _initialize() internal {
    (bool success,) = address(_roninGatewayV3).call(
      abi.encodeWithSignature(
        "initializeV4(address,address,address[],address[],uint64[])", _migrator, _pauseEnforcer, _ronTokens, _ronRecipients, _ronRemoteChainSelectors
      )
    );

    require(success, "GatewayV3_AssetMigration: failed to initialize V4");

    (success,) = address(_mainchainGatewayV3).call(
      abi.encodeWithSignature(
        "initializeV5(address,address,address[],address[],uint64[])", _migrator, _pauseEnforcer, _ethTokens, _ethRecipients, _ethRemoteChainSelectors
      )
    );

    require(success, "GatewayV3_AssetMigration: failed to initialize V5");
  }

  function testConcrete_RevertIf_Whitelisted_IsEOA() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWeth);
    whitelists[0] = makeAddr("alice");

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1000 ether;

    deal(address(_roninWeth), address(_roninGatewayV3), 1000 ether);

    vm.expectRevert();
    vm.prank(_migrator);
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_RevertIf_Whitelist_NullRemoteChainSelectors_But_WhitelistedSpender_IsMultiLane() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWeth);
    whitelists[0] = address(new MockCCIPPoolMultiLane(address(_roninWeth)));

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1000 ether;

    deal(address(_roninWeth), address(_roninGatewayV3), 1000 ether);

    vm.expectRevert();
    vm.prank(_migrator);
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_RevertIf_Whitelist_RemoteChainSelectors_But_WhitelistedSpender_IsSingleLane() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWeth);
    whitelists[0] = address(new MockCCIPPoolSingleLane(address(_roninWeth)));
    remoteChainSelectors[0] = uint64(uint256(keccak256("remote-chain-selector")));

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1000 ether;

    deal(address(_roninWeth), address(_roninGatewayV3), 1000 ether);

    vm.expectRevert();
    vm.prank(_migrator);
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_AutoWrap_If_Migrate_Native_MultiLane() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_mainchainWeth);
    whitelists[0] = address(new MockCCIPPoolMultiLane(address(_mainchainWeth)));
    remoteChainSelectors[0] = uint64(uint256(keccak256("remote-chain-selector")));

    address admin = LibProxy.getProxyAdmin(address(_mainchainGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_mainchainGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    vm.deal(address(_mainchainGatewayV3), 1000 ether);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1000 ether;
    tokens[0] = address(0x0);

    vm.prank(_migrator);
    _mainchainGatewayV3.migrateERC20(new address[](1), amounts);
  }

  function testConcrete_CanMigrate_IfWhitelisted_SingleLane() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWeth);
    whitelists[0] = address(new MockCCIPPoolSingleLane(address(_roninWeth)));

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    deal(address(_roninWeth), address(_roninGatewayV3), 1000 ether);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1000 ether;

    vm.prank(_migrator);
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_RevertIf_MigrateNative_RoninGatewayV3() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWron);
    whitelists[0] = makeAddr("whitelist");

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    uint256[] memory amounts = new uint256[](1);
    tokens[0] = address(0x0);
    amounts[0] = 1000 ether;

    vm.prank(_migrator);
    vm.expectRevert("Not implemented");
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_validConfig() external {
    assertEq(_roninGatewayV3.emergencyPauser(), _pauseEnforcer, "GatewayV3_AssetMigration: invalid emergency pauser");
    assertEq(_roninGatewayV3.getRoleMemberCount(_MIGRATOR_ROLE), 1, "GatewayV3_AssetMigration: invalid migrator count");
    assertEq(_roninGatewayV3.hasRole(_MIGRATOR_ROLE, _migrator), true, "GatewayV3_AssetMigration: invalid migrator role");
  }

  function testConcrete_RevertIf_WhitelistNativeToken() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(0x0);
    whitelists[0] = makeAddr("whitelist");

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    vm.expectRevert(IRoninGatewayV3.ErrWhitelistWrappedTokenInstead.selector);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );
  }

  function testConcrete_RevertIf_DeWhitelist_MultiLane() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = address(_roninWeth);
    whitelists[0] = address(new MockCCIPPoolMultiLane(address(_roninWeth)));
    remoteChainSelectors[0] = uint64(uint256(keccak256("remote-chain-selector")));

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    deal(address(_roninWeth), address(_roninGatewayV3), 1000 ether);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 100 ether;

    vm.prank(_migrator);
    _roninGatewayV3.migrateERC20(tokens, amounts);

    // De-whitelist
    whitelists[0] = address(0x0);
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    vm.prank(_migrator);
    vm.expectRevert(abi.encodeWithSelector(IRoninGatewayV3.ErrNotWhitelistedToken.selector, tokens[0]));
    _roninGatewayV3.migrateERC20(tokens, amounts);
  }

  function testConcrete_Admin_Can_Whitelist() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = makeAddr("token");
    whitelists[0] = makeAddr("whitelist");

    address admin = LibProxy.getProxyAdmin(address(_roninGatewayV3));
    vm.prank(admin);
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    assertEq(_roninGatewayV3.getWhitelistedAddresses(tokens)[0], whitelists[0], "GatewayV3_AssetMigration: invalid whitelist address");
  }

  function testConcrete_RevertIf_NotAdmin_Whitelist() external {
    address[] memory tokens = new address[](1);
    address[] memory whitelists = new address[](1);
    uint64[] memory remoteChainSelectors = new uint64[](1);

    tokens[0] = makeAddr("token");
    whitelists[0] = makeAddr("whitelist");

    address admin = _migrator;
    vm.prank(admin);
    vm.expectRevert();
    TransparentUpgradeableProxyV2(payable(address(_roninGatewayV3))).functionDelegateCall(
      abi.encodeCall(IRoninGatewayV3.whitelist, (tokens, whitelists, remoteChainSelectors))
    );

    vm.prank(admin);
    vm.expectRevert();
    _roninGatewayV3.whitelist(tokens, whitelists, remoteChainSelectors);
  }
}
