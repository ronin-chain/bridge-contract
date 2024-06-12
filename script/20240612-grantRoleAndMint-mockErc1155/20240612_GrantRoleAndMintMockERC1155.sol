pragma solidity ^0.8.19;

import { MockERC1155 } from "@ronin/contracts/mocks/token/MockERC1155.sol";

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";

contract MockERC1155_GrantRoleAndMint is Migration {
  bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public BURNER_ROLE = keccak256("BURNER_ROLE");

  address public MainchainGatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
  address public RoninGatewayV3 = 0xCee681C9108c42C710c6A8A949307D5F13C9F3ca;

  address public mockErc1155SepoliaAddress = 0xb40979a3FB2f76F640dcad2a6DF1264f62b7A6da;
  address public mockErc1155RoninAddress = 0x2B13110C6e3e2Cb1EFbA47897b65cFbf71f806d2;
  address public testnetAdmin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;

  MockERC1155 private _mockErc1155;

  function run() public virtual returns (MockERC1155) {
    _grantRoleAndMintSepolia();
    _grantRoleAndMintRonin();
  }

  function _grantRoleAndMintSepolia() internal {
    _mockErc1155 = MockERC1155(mockErc1155SepoliaAddress);

    vm.startBroadcast(testnetAdmin);

    _mockErc1155.grantRole(MINTER_ROLE, MainchainGatewayV3);
    _mockErc1155.grantRole(MINTER_ROLE, testnetAdmin);

    _mockErc1155.grantRole(BURNER_ROLE, MainchainGatewayV3);
    _mockErc1155.grantRole(BURNER_ROLE, testnetAdmin);

    _mockErc1155.mint(testnetAdmin, 0, 100, "");

    vm.stopBroadcast();
  }

  function _grantRoleAndMintRonin() internal {
    _mockErc1155 = MockERC1155(mockErc1155RoninAddress);

    vm.startBroadcast(testnetAdmin);

    _mockErc1155.grantRole(MINTER_ROLE, RoninGatewayV3);
    _mockErc1155.grantRole(MINTER_ROLE, testnetAdmin);

    _mockErc1155.grantRole(BURNER_ROLE, RoninGatewayV3);
    _mockErc1155.grantRole(BURNER_ROLE, testnetAdmin);

    _mockErc1155.mint(testnetAdmin, 0, 100, "");

    vm.stopBroadcast();
  }
}
