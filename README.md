# ronin-bridge-contracts

The collections of smart contracts that power the Ronin Bridge.

## Development

### Requirement

- [Foundry forge@^0.2.0](https://book.getfoundry.sh/)

### Build & Test

- Install packages

```shell
$ forge install
```

- Build contracts

```shell
$ forge build
```

- Run test

```shell
$ forge test
```

### Deploy

```shell
$ forge script <path/to/file.s.sol> -f --private-key <your_private_key>
```

## Target chain to deploy

This repo contains source code of contracts that will be either deployed on the mainchains, or on Ronin chain.

- On mainchains:
  - Governance contract: `MainchainGovernanceAdmin`
  - Bridge contract: `MainchainGatewayV3`
- On Ronin chain:
  - Governance contract: `RoninGovernanceAdmin`
  - Bridge operation: `RoninGatewayV3`

## Upgradeability & Governance mechanism

Except for the governance contracts and vault forwarder contracts, all other contracts are deployed following the proxy pattern for upgradeability. The [`TransparentUpgradeableProxyV2`](./contracts/extensions/TransparentUpgradeableProxyV2.sol), an extended version of [OpenZeppelin's](https://docs.openzeppelin.com/contracts/3.x/api/proxy#TransparentUpgradeableProxy), is used for deploying the proxies.

To comply with the [governance process](./docs/README.md#governance), in which requires all modifications to a contract must be approved by a set of governors, the admin role of all proxies must be granted for the governance contract address.

### Deployment steps

- Init the environment variables

  ```shell
  $ cp .env.example .env && vim .env
  ```

- Update the contract configuration in [`config.ts`](./src/config.ts) file

- Deploy the contracts

  ```shell
  $ yarn hardhat deploy --network <local|ronin-devnet|ronin-mainnet|ronin-testnet>
  ```

## Documentation

See [docs/README.md](./docs/README.md) for the documentation of the contracts.

See [docs/HACK.md](./docs/HACK.md) for the structure of the repo.

For the whitepaper, please refer to [Ronin Whitepaper](https://www.notion.so/skymavis/Ronin-Whitepaper-deec289d6cec49d38dc6e904669331a5).
