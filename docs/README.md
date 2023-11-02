# Documentation of the Bridge contracts

- [Bridges](#bridges)
  - [Deposits](#deposits)
  - [Withdrawals](#withdrawals)
- [Governance](#governance)
  - [Ronin Trusted Organization](#ronin-trusted-organization)
  - [Bridge Operators Ballot](#bridge-operators-ballot)
  - [Proposals](#proposals)

## Bridges

The bridge is design to support multiple chains.
When a deposit event happens on mainchain, the Bridge component in each validator node will pick it up and relay it to Ronin by sending a corresponding transaction. For withdrawal and governance events, it will start from Ronin then being relay on other chains.

### Deposits

Users can deposit ETH, ERC20, and ERC721 (NFTs) by sending transactions to `MainchainGatewayV3` and waiting for the deposit to be verified on Ronin. The validator will listen to the event on mainchain and then acknowledge the deposit on Ronin. The gateway should have a mapping between token contracts on Ethereum and on Ronin before the deposit can take place.

For deposit there is no restriction on how large a deposit can be.
![image](./assets/Deposit.png)

### Withdrawals

For withdrawal there are certain restrictions:

1. Withdrawal tiers

   There are 3 withdrawal tiers with different level of threshold required to withdraw. This is what we propose initially

   | Tier   |       Withdrawal Value        | Threshold                                                                                               |
   | ------ | :---------------------------: | ------------------------------------------------------------------------------------------------------- |
   | Tier 1 |               -               | The normal withdrawal/deposit threshold                                                                 |
   | Tier 2 | >= `highTierThreshold(token)` | Applied the special threshold for high-tier withdrawals                                                 |
   | Tier 3 |  >= `lockedThreshold(token)`  | Applied the special threshold for high-tier withdrawals, one additional human review to unlock the fund |

2. Daily withdrawal limit

   There will be another constraint on the number of token that can be withdraw in a day. We propose to cap the value at `dailyWithdrawalLimit(token)`. Since withdrawal of Tier 3 already requires human review, it will not be counted in daily withdrawal limit.

![image](./assets/Withdrawal.png)

_Normal withdrawal flow (tier 1 + tier 2). For tier 3, a separated human address will need to unlock the fund._

## Governance

We have a group of trusted organizations that are chosen by the community and Sky Mavis. Their tasks are to take part in the Validator set and govern the network configuration through the on-chain governance process:

- Update the system parameters, e.g: slash thresholds, and add/remove trusted organizations,...
- Sync the set of bridge operators to the Ethereum chain every period.

![image](./assets/Governance.png)

_Governance flow overview_

The governance contracts (`RoninGovernanceAdmin` and `MainchainGovernanceAdmin`) are mainly responsible for the governance process via a decentralized voting mechanism. At any instance, there will be maximum one governance vote going on per network.

### Ronin Trusted Organization

| Properties              | Explanation                                                                        |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `address consensusAddr` | Address of the validator that produces block. This is so-called validator address. |
| `address governor`      | Address to voting proposal                                                         |
| `address bridgeVoter`   | Address to voting bridge operators                                                 |
| `uint256 weight`        | Governor weight                                                                    |

### Bridge Operators Ballot

```js
// keccak256("BridgeOperatorsBallot(uint256 period,address[] operators)");
const TYPEHASH = 0xeea5e3908ac28cbdbbce8853e49444c558a0a03597e98ef19e6ff86162ed9ae3;
```

| Name        | Type        | Explanation                                |
| ----------- | ----------- | ------------------------------------------ |
| `period`    | `uint256`   | The period that these operators are active |
| `operators` | `address[]` | The address list of all operators          |

### Proposals

**Per-chain Proposal**

```js
// keccak256("ProposalDetail(uint256 nonce,uint256 chainId,address[] targets,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
const TYPE_HASH = 0x65526afa953b4e935ecd640e6905741252eedae157e79c37331ee8103c70019d;
```

| Name         | Type        | Explanation                                                   |
| ------------ | ----------- | ------------------------------------------------------------- |
| `nonce`      | `uint256`   | The proposal nonce                                            |
| `chainId`    | `uint256`   | The chain id to execute the proposal (id = 0 for all network) |
| `targets`    | `address[]` | List of address that the BridgeAdmin has to call              |
| `values`     | `uint256[]` | msg.value to send for targets                                 |
| `calldatas`  | `bytes[]`   | Data to call to the targets                                   |
| `gasAmounts` | `uint256[]` | Gas amount to call                                            |

**Global Proposal**

The governance has 4 target options to call to globally:

- Option 0: `BridgeManager` contract
- Option 1: `GatewayContract` contract
- Option 2: `BridgeReward` contract
- Option 3: `BridgeSlash` contract
- Option 4: `BridgeTracking` contract

```js
// keccak256("GlobalProposalDetail(uint256 nonce,uint8[] targetOptions,uint256[] values,bytes[] calldatas,uint256[] gasAmounts)");
const TYPE_HASH = 0xdb316eb400de2ddff92ab4255c0cd3cba634cd5236b93386ed9328b7d822d1c7;
```

| Name            | Type        | Explanation                   |
| --------------- | ----------- | ----------------------------- |
| `nonce`         | `uint256`   | The proposal nonce            |
| `targetOptions` | `uint8[]`   | List of options               |
| `values`        | `uint256[]` | msg.value to send for targets |
| `calldatas`     | `bytes[]`   | Data to call to the targets   |
| `gasAmounts`    | `uint256[]` | Gas amount to call            |
