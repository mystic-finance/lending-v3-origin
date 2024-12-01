# Aave V3.1 Origin

![Aave v3.1 Origin_banner](./v3-1-banner.jpeg)

Aave v3.1 complete codebase, Foundry-based.

[![Coverage badge](./report/coverage.svg)](https://aave-dao.github.io/aave-v3-origin)
<br>

## Dependencies

- Foundry, [how-to install](https://book.getfoundry.sh/getting-started/installation) (we recommend also update to the last version with `foundryup`)
- Lcov
  - Optional, only needed for coverage testing
  - For Ubuntu, you can install via `apt install lcov`
  - For Mac, you can install via `brew install lcov`

<br>

## Setup

```sh
cp .env.example .env

forge install

# optional, to install prettier
bun install
```

<br>

## Tests

- To run the full test suite: `make test`
- To re-generate the coverage report: `make coverage`

<br>

## Documentation

- [Aave v3 technical Paper](./techpaper/Aave_V3_Technical_Paper.pdf)
- [v3 to v3.0.2 production upgrade](https://github.com/bgd-labs/proposal-3.0.2-upgrade/blob/main/README.md)
- [Aave v3.1 features](./docs/Aave-v3.1-features.md)

<br>

## Security

Aave v3.1 is an upgraded version of Aave v3, more precisely on top of the initial Aave v3 release and a follow-up 3.0.2 later update.

The following are the security procedures historically applied to Aave v3.X versions.

<br>

**-> Aave v3**

- [ABDK](./audits/27-01-2022_ABDK_AaveV3.pdf)
- [OpenZeppelin](./audits/01-11-2021_OpenZeppelin_AaveV3.pdf)
- [Trail of Bits](./audits/07-01-2022_TrailOfBits_AaveV3.pdf)
- [Peckshield](./audits/14-01-2022_PeckShield_AaveV3.pdf)
- [SigmaPrime](./audits/27-01-2022_SigmaPrime_AaveV3.pdf)
- [Certora](./certora/Aave_V3_Formal_Verification_Report_Jan2022.pdf)

<br>

**-> Aave v3.0.1 - December 2022**

- [PeckShield](./audits/09-12-2022_PeckShield_AaveV3-0-1.pdf)
- [SigmaPrime](./audits/23-12-2022_SigmaPrime_AaveV3-0-1.pdf)

<br>

**-> Aave v3.0.2 - April 2023**

- [SigmaPrime](./audits/19-04-2023_SigmaPrime_AaveV3-0-2.pdf)
- [Certora](./audits/03-2023_2023_Certora_AaveV3-0-2.pdf)

<br>

**-> Aave v3.1 - April 2024**

- [Certora](./audits/30-04-2024_Certora_AaveV3.1.pdf)
- [MixBytes](./audits/02-05-2024_MixBytes_AaveV3.1.pdf)
- An internal review by [SterMi](https://twitter.com/stermi) on the virtual accounting feature was conducted on an initial phase of the codebase.
- Additionally, Certora properties have been improved over time since the Aave v3 release. More details [HERE](./certora/README.md).

<br>

### Bug bounty

This repository will be subjected to [this bug bounty](https://immunefi.com/bounty/aave/) once the Aave Governance upgrades the smart contracts in the applicable production instances.

<br>

## License

Copyright © 2024, Aave DAO, represented by its governance smart contracts.

The [BUSL1.1](./LICENSE) license of this repository allows for any usage of the software, if respecting the Additional Use Grant limitations, forbidding any use case damaging anyhow the Aave DAO's interests.
Interfaces and other components required for integrations are explicitly MIT licensed.

## Contracts in scope

- src/core/contracts/protocol/partner/KYCPortal.sol
- src/core/contracts/protocol/partner/Timelock.sol
- src/core/contracts/protocol/partner/KYCId.sol
- src/core/contracts/protocol/partner/CustodyController.sol
- src/core/contracts/protocol/pool/SemiPermissionedPool.sol
- src/core/contracts/protocol/vault/Vault.sol
- src/core/contracts/protocol/vault/VaultFactory.sol
- src/core/contracts/protocol/vault/VaultController.sol
- src/core/contracts/protocol/libraries/logic/BorrowLogic.sol
- src/core/contracts/protocol/libraries/logic/BridgeLogic.sol
- src/core/contracts/protocol/libraries/logic/LiquidationLogic.sol
- src/core/contracts/protocol/libraries/logic/SupplyLogic.sol
- src/core/contracts/protocol/tokenization/AToken.sol
- src/core/contracts/protocol/configuration/ACLManager.sol
- src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol

## Additions

### Vaults

It is designed to mimic the Morpho vault with curators creating new vaults. A number of pools can be added to the ERC4626 vault provided the pool supports the underlying token of the vault. The vault controller is to remove the headache of choosing the sutiable vaults for your token and getting the best performing vaults to deposit you money into, while supporting multiple tokens at once.

## KYC
The KYCId.sol and KYCPortal.sol are the primary contracts under KYC. The ownership of the portal is sent to the timelock contract as a form of temporarily renounce ownership of the KYCportal as it is desigend to ge run by bots majorly.

## Custody

Due to the nature of the tokens to be used in the pools, some tokens would be transferred to a third party custody through the custody controller. To perform any transction that takes a token out of the custody and pool, you first submit a withdrawal request with the target and calldata you wish to call e.g withdraw 50 usdc from pool 0x003.... The custodian bot initiates withdrawal to the custody controller then calls the update status to transfer the token freshly withdrawn to the needed AToken address (one custody controller per reserve)
