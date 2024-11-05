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

    config.marketId = 'Mystic Arbitrum Mainnet Market';
    config.providerId = 8088;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
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
    IAaveV3ConfigEngine.Listing[] memory listings = new IAaveV3ConfigEngine.Listing[](3);
    // IAaveV3ConfigEngine.Listing[] memory listingCollateral = new IAaveV3ConfigEngine.Listing[](1);

    listings[0] = IAaveV3ConfigEngine.Listing({
      //borrow asset
      asset: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
      assetSymbol: 'USDC',
      priceFeed: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 70_00,
        baseVariableBorrowRate: 1_5, // 1.75%
        variableRateSlope1: 10_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 70_00, // 90%
      liqThreshold: 70_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, //0, // 100k USD
      liqProtocolFee: 5_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x0000206329b97DB379d5E1Bf586BbDB969C63274,
      assetSymbol: 'USDA',
      priceFeed: 0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7, //USDT
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 70_00,
        baseVariableBorrowRate: 1_5, // 1.75%
        variableRateSlope1: 10_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 70_00, // 90%
      liqThreshold: 70_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, //0, // 100k USD
      liqProtocolFee: 5_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[2] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x1e2C4fb7eDE391d116E6B41cD0608260e8801D59,
      assetSymbol: 'bCSPX',
      priceFeed: 0x9BCAb090873aE5f2200DCF1Eb51EE0684D82B27C,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 70_00,
        baseVariableBorrowRate: 1_5,
        variableRateSlope1: 15_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 70_00, // 90%
      liqThreshold: 70_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, //0, // 100k USD
      liqProtocolFee: 5_00, // 10%
      eModeCategory: 0 // No category
    });

    // listings[3] = IAaveV3ConfigEngine.Listing({
    //   //collateral
    //   asset: 0x401eCb1D350407f13ba348573E5630B83638E30D,
    //   assetSymbol: 'USDC.e',
    //   priceFeed: 0x6C174e1D1b2244F45173b0feC10ba218E3f4D073,
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
    //   debtCeiling: 0, //0, // 100k USD
    //   liqProtocolFee: 5_00, // 10%
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
      networkName: 'Arbitrum Mainnet Market',
      networkAbbreviation: 'ArbMainnet'
    });
    config.listings = listings;
    config.treasury = 0x16cEEE76D2f114C10a5703b885EBA7cd163A7D3b;
    config.interestRateStrategy = 0xFB910cD1bA7295B9e03DDE8EfAAF69682F509f7C;
    config.poolConfigurator = 0xC59bE993108052Aa9cd9b082B28d6C44dA58ae65;
    config.rewardsController = 0x0F5052665AaC65116864Ef638169A06f3c5a801a;
    config.poolProxy = 0x504193dBFdEad383ddfE1eC4B3834Ed7Dfd87b44;
    config.oracle = 0x25aF9EABD5822Fc178Dedd6CfdB94C30AE26c1d7;
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
