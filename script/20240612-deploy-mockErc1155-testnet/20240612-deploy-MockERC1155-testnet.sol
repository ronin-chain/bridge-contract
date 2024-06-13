pragma solidity ^0.8.19;

import { MockERC1155 } from "@ronin/contracts/mocks/token/MockERC1155.sol";
import { MockERC1155Deploy } from "../contracts/token/MockERC1155Deploy.s.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { Network } from "../utils/Network.sol";

contract Migration__Deploy_MockERC1155_Testnet is Migration {
  bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public BURNER_ROLE = keccak256("BURNER_ROLE");

  address public GatewayV3 = 0xCee681C9108c42C710c6A8A949307D5F13C9F3ca;

  address public defaultAdmin = 0xEf46169CD1e954aB10D5e4C280737D9b92d0a936;
  address public testnetAdmin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;

  MockERC1155 private _mockErc1155;

  function run() public virtual returns (MockERC1155) {
   if (network() == Network.Sepolia.key())  {
      GatewayV3 = 0x06855f31dF1d3D25cE486CF09dB49bDa535D2a9e;
    }
    _mockErc1155 = new MockERC1155Deploy().run();
    _grantRoleAndMint();
  }

  function _grantRoleAndMint() internal {
    vm.startBroadcast(defaultAdmin);

    _mockErc1155.grantRole(MINTER_ROLE, defaultAdmin);
    _mockErc1155.grantRole(MINTER_ROLE, GatewayV3);
    _mockErc1155.grantRole(MINTER_ROLE, testnetAdmin);

    _mockErc1155.grantRole(BURNER_ROLE, GatewayV3);
    _mockErc1155.grantRole(BURNER_ROLE, testnetAdmin);

    _mockErc1155.mint(testnetAdmin, 0, 100, "");

    _mockErc1155.grantRole(0x00, testnetAdmin);

    vm.stopBroadcast();
  }
}
