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

## Addresses Reports (Plume Testnet chain)

USDC/USDT MArket

```javascript


{
  "aToken": "0xd6C2842B63b04CcDaCA2574c9956CBC8aa2c4AAD",
  "aave-v3-factory-branch": "plume-market-usdc-usdt",
  "aave-v3-factory-commit": "11c7187f624fb3093dcfd0419c94e6c16e4886ee",
  "aaveOracle": "0x0186033cA9088cd6C1d793bc45b201c6bb21721d",
  "aaveParaSwapFeeClaimer": "0x0000000000000000000000000000000000000000",
  "aclManager": "0x91989F2609DB51F07cEb7F94cDa866dcb9e29B27",
  "arcKycPortal": "0xA85206d14d5C0fC88D60dFAED7d7891f99f700c3",
  "arcTimelock": "0x42eF942275605a0d8dF85cAc7e1Ead0c8dA2346F",
  "deployEngine": "0x0000000000000000000000000000000000000000",
  "emissionManager": "0x8f1e5E73b7811FD358159491237a6F506C4FC662",
  "interestRateStrategy": "0x2E41A96c76f44ACc67A0F733CC309799E6496B5b",
  "l2Encoder": "0xC8f6143E1fBFa0a96113efEC126c347f44eDf34E",
  "paraSwapLiquiditySwapAdapter": "0x0000000000000000000000000000000000000000",
  "paraSwapRepayAdapter": "0x0000000000000000000000000000000000000000",
  "paraSwapWithdrawSwapAdapter": "0x0000000000000000000000000000000000000000",
  "poolAddressesProvider": "0x0d8831D23Dad4FCD9cB73Ab777863E1E6f5C3a9f",
  "poolAddressesProviderRegistry": "0x1A1d9065b4d705484706ADc2D7a147d128a34296",
  "poolConfiguratorImplementation": "0xf1e3518E8d9744201823Ce884fFE34599423CC44",
  "poolConfiguratorProxy": "0x351282c2e2F1273083c9aeA37B1E0fE540ABF649",
  "poolImplementation": "0xa17467CdB8b9CF630D487280f925E4AD7d8c651b",
  "poolProxy": "0xe40E9E9a11DFbF488320150360754c8D9DF10eF3",
  "protocolDataProvider": "0xFD24Be04a53D709A5b3ef440A98dd124b5870B19",
  "proxyAdmin": "0x8B6d1618b944306A8718D796f235e614683AF927",
  "rewardsControllerImplementation": "0x66a5dF6577F593c4eA36f7Bb396C1c666f1Ccc9E",
  "rewardsControllerProxy": "0x76eb7Fe95F262D048CF256c333b665e8F47D93eE",
  "stableDebtToken": "0xf2CC3fC8b98954b0F797c1491b1151615Aa3Ae9B",
  "treasury": "0x5BB548c3B66c29D2C29B57913b55419aD630e778",
  "treasuryImplementation": "0x106af5B2e4C01580AD0AcbD116F0b22A73d42e25",
  "uiIncentiveDataProvider": "0x6E0E781D15f2652739dF9970AD8F2C3d362bBe90",
  "uiPoolDataProvider": "0x0000000000000000000000000000000000000000",
  "variableDebtToken": "0x8419B557028bAbf1F2F0c524F9B139C06771aB80",
  "walletBalanceProvider": "0x160Af61e7C909aC1b7384b6B097fcAf69bf5aAe8",
  "wrappedTokenGateway": "0x0000000000000000000000000000000000000000",
  "aTokenUSDC": "0xEC8db7E052D1D2304B0d5563f80b72268D4E7072",
  "aTokenUSDT": "0x006413433bdBAAD01798366Ff5241889d3DB1CcF",
  "sTokenUSDC": "0x2D134d0D416C68b5aFBDD9ef2D6bdc07EED4Bd0d",
  "sTokenUSDT": "0x2b66F2f22680A6730bD94E5aDCFaB43d739441aF",
  "vTokenUSDC": "0x35852B8cD4F5F027e43919e4E1982Eb282b79d14",
  "vTokenUSDT": "0xbd988D100b04D6FC907ef4CA778Fc531b605361c",
  "USDC":"0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1",
  "USDT":"0xc0aA307598C610AbF556319d8cB685D21d460ce7" (example rwa token)
}

```
