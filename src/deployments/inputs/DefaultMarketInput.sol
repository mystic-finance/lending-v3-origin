// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {IAaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'src/periphery/contracts/v3-config-engine/EngineFlags.sol';

contract DefaultMarketInput is MarketInput {
  function _getMarketInput(
    address deployer
  )
    internal
    view
    override
    returns (
      Roles memory roles,
      MarketConfig memory config,
      SubMarketConfig memory subConfig,
      DeployFlags memory flags,
      MarketReport memory deployedContracts
    )
  {
    roles.marketOwner = deployer;
    roles.emergencyAdmin = deployer;
    roles.poolAdmin = deployer;

    config.marketId = 'Aave V3 Mystic Sepolia Market';
    config.providerId = 8088;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0xeA3B617b74C2cEc6Aa6DE6527f04c1528e3C6503;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0xeA3B617b74C2cEc6Aa6DE6527f04c1528e3C6503;
    config.wrappedNativeToken = address(0);

    subConfig.timelock = address(0);
    subConfig.kycPortal = address(0);
    subConfig.underlyingAsset = address(0);
    subConfig.debtAsset = address(0);
    subConfig.create2_factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C; //0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    deployedContracts.poolAddressesProviderRegistry = address(0);
    flags.l2 = true;

    return (roles, config, subConfig, flags, deployedContracts);
  }

  function _listAsset(
    address deployer,
    address debtAsset,
    address collateralAsset
  ) internal view override returns (ListingConfig memory config) {
    IAaveV3ConfigEngine.Listing[] memory listings = new IAaveV3ConfigEngine.Listing[](2);
    IAaveV3ConfigEngine.Listing[] memory listingCollateral = new IAaveV3ConfigEngine.Listing[](1);

    listings[0] = IAaveV3ConfigEngine.Listing({
      //borrow asset
      asset: 0xEa0c23A2411729073Ed52fF94b38FceffE82FDE3,
      assetSymbol: 'PUSD',
      priceFeed: 0xeA3B617b74C2cEc6Aa6DE6527f04c1528e3C6503,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_50, // 1%
        variableRateSlope1: 4_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 88_00, // 90%
      liqThreshold: 88_50, // 92.5%
      liqBonus: 10_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 10_000_000, //0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0xc4FD844B1d074219bfC3A963920951d3604C88f0,
      assetSymbol: 'WETH',
      priceFeed: 0xBdf2dC39aEd22e8CC605b76a6024197acDF93Bc4,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_50, // 1.25%
        variableRateSlope1: 4_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 88_00, // 90%
      liqThreshold: 88_50, // 92.5%
      liqBonus: 10_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 10_000_000, //0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    // listings[2] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0x93b19315A575532907DeB0FA63Bbd74972934784,
    //   assetSymbol: 'wstETH',
    //   priceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
    //   rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
    //     optimalUsageRatio: 85_00,
    //     baseVariableBorrowRate: 1_50, // 1.25%
    //     variableRateSlope1: 4_00,
    //     variableRateSlope2: 70_00
    //   }),
    //   enabledToBorrow: EngineFlags.ENABLED,
    //   flashloanable: EngineFlags.DISABLED,
    //   stableRateModeEnabled: EngineFlags.DISABLED,
    //   borrowableInIsolation: EngineFlags.ENABLED,
    //   withSiloedBorrowing: EngineFlags.DISABLED,
    //   ltv: 88_00, // 90%
    //   liqThreshold: 88_50, // 92.5%
    //   liqBonus: 10_00, // 5%
    //   reserveFactor: 15_00, // 10%
    //   supplyCap: 50_000_000_000, // 100k AAVE
    //   borrowCap: 50_000_000_000, // 60k AAVE
    //   debtCeiling: 10_000_000, //0, // 100k USD
    //   liqProtocolFee: 10_00, // 10%
    //   eModeCategory: 0 // No category
    // });

    // listings[3] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
    //   assetSymbol: 'LINK',
    //   priceFeed: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,
    //   rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
    //     optimalUsageRatio: 85_00,
    //     baseVariableBorrowRate: 1_50, // 1.25%
    //     variableRateSlope1: 4_00,
    //     variableRateSlope2: 70_00
    //   }),
    //   enabledToBorrow: EngineFlags.ENABLED,
    //   flashloanable: EngineFlags.DISABLED,
    //   stableRateModeEnabled: EngineFlags.DISABLED,
    //   borrowableInIsolation: EngineFlags.ENABLED,
    //   withSiloedBorrowing: EngineFlags.DISABLED,
    //   ltv: 88_00, // 90%
    //   liqThreshold: 88_50, // 92.5%
    //   liqBonus: 10_00, // 5%
    //   reserveFactor: 15_00, // 10%
    //   supplyCap: 50_000_000_000, // 100k AAVE
    //   borrowCap: 50_000_000_000, // 60k AAVE
    //   debtCeiling: 10_000_000, //0, // 100k USD
    //   liqProtocolFee: 10_00, // 10%
    //   eModeCategory: 0 // No category
    // });

    // listings[4] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d,
    //   assetSymbol: 'USDC',
    //   priceFeed: 0x0153002d20B96532C639313c2d54c3dA09109309,
    //   rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
    //     optimalUsageRatio: 85_00,
    //     baseVariableBorrowRate: 1_50, // 1.25%
    //     variableRateSlope1: 4_00,
    //     variableRateSlope2: 70_00
    //   }),
    //   enabledToBorrow: EngineFlags.ENABLED,
    //   flashloanable: EngineFlags.DISABLED,
    //   stableRateModeEnabled: EngineFlags.DISABLED,
    //   borrowableInIsolation: EngineFlags.ENABLED,
    //   withSiloedBorrowing: EngineFlags.DISABLED,
    //   ltv: 88_00, // 90%
    //   liqThreshold: 88_50, // 92.5%
    //   liqBonus: 10_00, // 5%
    //   reserveFactor: 15_00, // 10%
    //   supplyCap: 50_000_000_000, // 100k AAVE
    //   borrowCap: 50_000_000_000, // 60k AAVE
    //   debtCeiling: 10_000_000, //0, // 100k USD
    //   liqProtocolFee: 10_00, // 10%
    //   eModeCategory: 0 // No category
    // });

    // listings[5] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0x30fA2FbE15c1EaDfbEF28C188b7B8dbd3c1Ff2eB,
    //   assetSymbol: 'USDT',
    //   priceFeed: 0x80EDee6f667eCc9f63a0a6f55578F870651f06A4,
    //   rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
    //     optimalUsageRatio: 85_00,
    //     baseVariableBorrowRate: 1_50, // 1.25%
    //     variableRateSlope1: 4_00,
    //     variableRateSlope2: 70_00
    //   }),
    //   enabledToBorrow: EngineFlags.ENABLED,
    //   flashloanable: EngineFlags.DISABLED,
    //   stableRateModeEnabled: EngineFlags.DISABLED,
    //   borrowableInIsolation: EngineFlags.ENABLED,
    //   withSiloedBorrowing: EngineFlags.DISABLED,
    //   ltv: 88_00, // 90%
    //   liqThreshold: 88_50, // 92.5%
    //   liqBonus: 10_00, // 5%
    //   reserveFactor: 15_00, // 10%
    //   supplyCap: 50_000_000_000, // 100k AAVE
    //   borrowCap: 50_000_000_000, // 60k AAVE
    //   debtCeiling: 10_000_000, //0, // 100k USD
    //   liqProtocolFee: 10_00, // 10%
    //   eModeCategory: 0 // No category
    // });

    // listings[6] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0x912CE59144191C1204E64559FE8253a0e49E6548,
    //   assetSymbol: 'ARB',
    //   priceFeed: 0xD1092a65338d049DB68D7Be6bD89d17a0929945e,
    //   rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
    //     optimalUsageRatio: 85_00,
    //     baseVariableBorrowRate: 1_50, // 1.25%
    //     variableRateSlope1: 4_00,
    //     variableRateSlope2: 70_00
    //   }),
    //   enabledToBorrow: EngineFlags.ENABLED,
    //   flashloanable: EngineFlags.DISABLED,
    //   stableRateModeEnabled: EngineFlags.DISABLED,
    //   borrowableInIsolation: EngineFlags.ENABLED,
    //   withSiloedBorrowing: EngineFlags.DISABLED,
    //   ltv: 88_00, // 90%
    //   liqThreshold: 88_50, // 92.5%
    //   liqBonus: 10_00, // 5%
    //   reserveFactor: 15_00, // 10%
    //   supplyCap: 50_000_000_000, // 100k AAVE
    //   borrowCap: 50_000_000_000, // 60k AAVE
    //   debtCeiling: 10_000_000, //0, // 100k USD
    //   liqProtocolFee: 10_00, // 10%
    //   eModeCategory: 0 // No category
    // });

    config.poolContext = IAaveV3ConfigEngine.PoolContext({
      networkName: 'Plume DevNet Market',
      networkAbbreviation: 'PlumeDevNet'
    });
    config.listings = listings;
    config.treasury = 0x7133d9d3d22471EC53D929eCA1AEe233b63c67f2;
    config.interestRateStrategy = 0x47B61Fa5AD31CEE6a04a6d718aC4f9a34129A19b;
    config.poolConfigurator = 0x246C014E3fB086885cd17B9CaCC99fbCf7b3A82f;
    config.rewardsController = 0x5b13f6884FD023a696674f7Eb06Ea82663869393;
    config.poolProxy = 0xDB487bEe0814E561706D4e1c002d565470D02bFe;
    config.oracle = 0x7e8CB03f969c99D3660f27545fb70C1a60F0a3Ac;
    return (config);
  }

  function _updateCollateral(
    address deployer,
    address collateralAsset
  ) internal view override returns (ListingConfig memory config) {
    config.collateralUpdate = IAaveV3ConfigEngine.CollateralUpdate({
      asset: collateralAsset,
      ltv: 60_00,
      liqThreshold: 70_00,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: 7_00
    });

    return (config);
  }

  function _updateBorrowAsset(
    address deployer,
    address debtAsset
  ) internal view override returns (ListingConfig memory config) {
    config.borrowUpdate = IAaveV3ConfigEngine.BorrowUpdate({
      asset: debtAsset,
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.KEEP_CURRENT,
      stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
      borrowableInIsolation: EngineFlags.KEEP_CURRENT,
      withSiloedBorrowing: EngineFlags.KEEP_CURRENT,
      reserveFactor: 15_00 // 15%
    });

    return (config);
  }
}

// borrowable asset is same as deposit and supply asset
// collateral assets is collateral for borring borrowable assets
// APY of supply >> APY of borrow
