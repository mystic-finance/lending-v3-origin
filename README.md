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

```javascript
{
"aToken": "0x43eeF9D91024Ece0440aaF046Cf53C470Cf041Ce",
"aave-v3-factory-branch": "main",
"aave-v3-factory-commit": "ac572975faf3690209a5681a7ad259af874ce3e1",
"aaveOracle": "0xCB594bE528eb3D06bd14D7Edf83F13695e7c5448",
"aaveParaSwapFeeClaimer": "0x0000000000000000000000000000000000000000",
"aclManager": "0x6b03a72DdFb08955eA5187C9C3639Ce176Cc5e93",
"arcKycPortal": "0x374BAaC91E73207D6f46f1e1585b0A03E6e4F474",
"arcTimelock": "0x335fF9a56b51F60230e017E6f0bC365c54e648d6",
"deployEngine": "0x0000000000000000000000000000000000000000",
"emissionManager": "0xB9849B8ae70db5186CAac971816523FE58BF491F",
"interestRateStrategy": "0xd7E9886c895a307F58b14B70F2cd8bC3ef0C6650",
"l2Encoder": "0x00ec761A7b91B75A829Cc46Ac485Cf4FfE14DDFB",
"paraSwapLiquiditySwapAdapter": "0x0000000000000000000000000000000000000000",
"paraSwapRepayAdapter": "0x0000000000000000000000000000000000000000",
"paraSwapWithdrawSwapAdapter": "0x0000000000000000000000000000000000000000",
"poolAddressesProvider": "0x9585E796d2D3EBf0e085C2ed85C499C4D9fbd908",
"poolAddressesProviderRegistry": "0x901DCb3bfBa00B79D1053FaE170f51f95639E3bf",
"poolConfiguratorImplementation": "0xe9c8233306Dee92afDb81b85ED1134750D91AF8e",
"poolConfiguratorProxy": "0x10BF67A7f42FBbcB6f5C4302f33Cd3Ef17af095b",
"poolImplementation": "0x3370fddcfa609bFDeFD5dAD6B507DE41D15c1341",
"poolProxy": "0xb8b46BDC1B85E0d22d61218e750b2BbAE0fA5e45",
"protocolDataProvider": "0x8264F47a73d9A1Cfa969847A1C740C84e35aF332",
"proxyAdmin": "0x78AF58148a67ccdfEE7e971571A1534826f3FEa1",
"rewardsControllerImplementation": "0x61f2aefEAB4BbE69Fc440b26B7C15b5200424aD3",
"rewardsControllerProxy": "0xDb1a70f828679e342b2AB9b62E4C2a29fcC37957",
"stableDebtToken": "0xB45cCdBa2d7592AD93b84dF7782084915c4595d2",
"treasury": "0x3F36849c1f7Fc7a58A503604790D457ab8bB8062",
"treasuryImplementation": "0x6c799feE024F0Ae9c42345Aa2836f39E51b1d80a",
"uiIncentiveDataProvider": "0x3A79AFab8E651ADaF418Ef0da5AAd53FB6a9B387",
"uiPoolDataProvider": "0x0000000000000000000000000000000000000000",
"variableDebtToken": "0xC2291CAa684f38603E3bAfAbD3a8EE8B57EdeE78",
"walletBalanceProvider": "0xfefACD17fB19E63ad1ccB3E17EcD22001987E67B",
"wrappedTokenGateway": "0x0000000000000000000000000000000000000000",
"aTokenUSDC": "0x635ce2feb661533c9507C9705B0b4b8729B50dA2",
"aTokenLandShare": "0xdC632E8277f072438011C42fBF649F5244fAcE39",
"sTokenUSDC": "0x3117b5150fa46eBc12Aa3C14A4B0cae861FF3C55",
"sTokenLandShare": "0xba473e4094556e3bE29C623f546de0bEad4D06E8",
"vTokenUSDC": "0x9FBbd1246b78Bf9809fBE9F6F6cB1E23Efc9D6EB",
"vTokenLandShare": "0xE2F8851f1C009236333eB8D9b2BA5201D584345F",
"USDC":"0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1",
"LandShare":"0xc708ff370fC21D3E48849B56a167a1c91A1D48D0" (example rwa token)
}
```
