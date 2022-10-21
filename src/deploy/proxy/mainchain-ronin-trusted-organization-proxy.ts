import { network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { roninTrustedOrganizationConf, mainchainNetworks, mainchainInitAddress } from '../../config';
import { verifyAddress } from '../../script/verify-address';
import { RoninTrustedOrganization__factory } from '../../types';

const deploy = async ({ getNamedAccounts, deployments }: HardhatRuntimeEnvironment) => {
  if (!mainchainNetworks.includes(network.name!)) {
    return;
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const logicContract = await deployments.get('RoninTrustedOrganizationLogic');
  const data = new RoninTrustedOrganization__factory().interface.encodeFunctionData('initialize', [
    roninTrustedOrganizationConf[network.name]!.trustedOrganizations,
    roninTrustedOrganizationConf[network.name]!.numerator,
    roninTrustedOrganizationConf[network.name]!.denominator,
  ]);

  const deployment = await deploy('MainchainRoninTrustedOrganizationProxy', {
    contract: 'TransparentUpgradeableProxyV2',
    from: deployer,
    log: true,
    args: [logicContract.address, mainchainInitAddress[network.name].governanceAdmin?.address, data],
    nonce: mainchainInitAddress[network.name].roninTrustedOrganizationContract?.nonce,
  });
  verifyAddress(deployment.address, mainchainInitAddress[network.name].roninTrustedOrganizationContract?.address);
};

deploy.tags = ['MainchainRoninTrustedOrganizationProxy'];
deploy.dependencies = ['RoninTrustedOrganizationLogic', 'MainchainGovernanceAdmin'];

export default deploy;