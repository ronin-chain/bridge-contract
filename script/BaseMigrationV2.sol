// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "foundry-deployment-kit/BaseMigration.s.sol";

abstract contract BaseMigrationV2 is BaseMigration {
  using StdStyle for *;
  using LibString for bytes32;
  using LibProxy for address payable;

  function _deployProxy(TContract contractType, bytes memory args)
    internal
    virtual
    override
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = CONFIG.getContractName(contractType);

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
      string.concat(
        "BaseMigration: Invalid proxy admin\n",
        "Actual: ",
        vm.toString(actualProxyAdmin),
        "\nExpected: ",
        vm.toString(proxyAdmin)
      )
    );

    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(
      sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }
}
