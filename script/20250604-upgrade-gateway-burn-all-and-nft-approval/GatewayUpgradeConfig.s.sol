// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Migration } from "../Migration.s.sol";

abstract contract GatewayUpgradeConfig is Migration {
  // DEFAULT EXPIRY DURATION
  uint256 internal constant _DEFAULT_EXPIRY_DURATION = 14 days;

  // SM Governor (same for both chains)
  address internal constant _SM_GOVERNOR = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;

  // SM Executor (same for both chains)
  address internal constant _SM_EXECUTOR = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;

  // Logic contract addresses
  address internal constant _BURN_ALL_LOGIC = 0x838ac25e9998a3486Db5eB956F8B2fE894c1c6e0;
  address internal constant _NFT_APPROVAL_LOGIC_RONIN = 0x5019d41B0737e39B51Fd6dA4859F3e27579E4e69;
  address internal constant _NFT_APPROVAL_LOGIC_MAINCHAIN = 0x5019d41B0737e39B51Fd6dA4859F3e27579E4e69;

  // NFT operator address (same for both chains)
  address internal constant _NFT_OPERATOR = 0xab5F1EB5B88c77651EEd32104b19e34F36675893;

  // NFT addresses for Ronin chain
  address[] internal _roninNfts = [
    0x241A81fC0d6692707DAd2B5025a3a7CF2CF25aCF, // CyberKongz VX
    0xF083289535052E8449D69e6dc41c0aE064d8e3f6, // Farm Land by Pixels
    0x1F7c16FCe4fC894143aFB5545Bf04f676bf7DCf3, // Genkai
    0x342fcFC16943A930251d15fCCdCD95104F9B4E5f // Cambria Founders
  ];

  // NFT addresses for Mainchain (Ethereum)
  address[] internal _mainchainNfts = [
    0x7EA3Cca10668B8346aeC0bf1844A49e995527c8B, // CyberKongz VX
    0x5C1A0CC6DAdf4d0fB31425461df35Ba80fCBc110, // Farm Land by Pixels
    0x1F7c16FCe4fC894143aFB5545Bf04f676bf7DCf3, // Genkai
    0xE41Af8c3F0decf206c3AFb9DBf2E7643F349E0b9 // Cambria Founders
  ];

  function _createNftOperatorArrays(
    uint256 length
  ) internal pure returns (address[] memory operators, bool[] memory approveds) {
    operators = new address[](length);
    approveds = new bool[](length);

    for (uint256 i = 0; i < length; i++) {
      operators[i] = _NFT_OPERATOR;
      approveds[i] = true;
    }
  }

  function _getRoninNftData() internal view returns (address[] memory nfts, address[] memory operators, bool[] memory approveds) {
    nfts = _roninNfts;
    (operators, approveds) = _createNftOperatorArrays(_roninNfts.length);
  }

  function _getMainchainNftData() internal view returns (address[] memory nfts, address[] memory operators, bool[] memory approveds) {
    nfts = _mainchainNfts;
    (operators, approveds) = _createNftOperatorArrays(_mainchainNfts.length);
  }
}
