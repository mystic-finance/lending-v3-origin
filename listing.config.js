export const configs = {
  "USDC/USDT": [
    {
      //borrow asset
      asset: 0xea237441c92cae6fc17caaf9a7acb3f953be4bd1,
      assetSymbol: "USDC",
      priceFeed: 0x34d75eb977f06a53362900d3f09f7edee324afe8,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 25, // 0.25%
        variableRateSlope1: 4_00,
        variableRateSlope2: 75_00,
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.ENABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 70.5%
      liqThreshold: 0, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_00, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0, // No category
    },
    {
      //collateral
      asset: 0x4632403a83fb736ab2c76b4c32fac9f81e2cfce2,
      assetSymbol: "USDT",
      priceFeed: 0x34d75eb977f06a53362900d3f09f7edee324afe8,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 25, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 60_00,
      }),
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 90_00, // 70.5%
      liqThreshold: 90_50, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 10, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0, // No category
    },
  ],
  "DAI/WETH": [
    {
      //borrow asset
      asset: 0x1aa70741167155e08bd319be096c94ee54c6ca19,
      assetSymbol: "DAI",
      priceFeed: 0x34d75eb977f06a53362900d3f09f7edee324afe8,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 55, // 0.25%
        variableRateSlope1: 4_00,
        variableRateSlope2: 75_00,
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 70.5%
      liqThreshold: 0, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_00, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0, // No category
    },
    {
      //collateral
      asset: 0x99835d80000f6998015ada61fb88f6f94f3759fe,
      assetSymbol: "WETH",
      priceFeed: 0x32c3be69beb6628ebbbf2a826d862d68e77dbdc9,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 55, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 60_00,
      }),
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 70.5%
      liqThreshold: 80_50, // 76%
      liqBonus: 10_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 10, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0, // No category
    },
  ],
};
