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

    config.marketId = 'Aave V3 Mystic Plume Mainnet Market';
    config.providerId = 8088;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0xE067A9905fD0d5760F747329DBd6CA175a6677f2;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0xE067A9905fD0d5760F747329DBd6CA175a6677f2;
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
    IAaveV3ConfigEngine.Listing[] memory listingCollateral = new IAaveV3ConfigEngine.Listing[](1);

    listings[0] = IAaveV3ConfigEngine.Listing({
      //borrow asset
      asset: 0x360822f796975cEccD8095c10720c57567b4199f,
      assetSymbol: 'pUSD',
      priceFeed: 0xA2B05F84130Ee6a6F324BFFaA7FF9fA32305c21e,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 1_50, // 1%
        variableRateSlope1: 8_00,
        variableRateSlope2: 60_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 90_00, // 90%
      liqThreshold: 90_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 100_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x11476323D8DFCBAFac942588E2f38823d2Dd308e,
      assetSymbol: 'pETH',
      priceFeed: 0x9025Ea91308E0A55980e8cA6339026d3d662EB00,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 1_50, // 1.25%
        variableRateSlope1: 12_00,
        variableRateSlope2: 200_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 90%
      liqThreshold: 81_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 10_000_000, // 100k AAVE
      borrowCap: 10_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[2] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x3938A812c54304fEffD266C7E2E70B48F9475aD6,
      assetSymbol: 'USDC.e',
      priceFeed: 0x5cE034374a7E62e42a1816C00A631437317a8eF9,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 1_50, // 1%
        variableRateSlope1: 8_00,
        variableRateSlope2: 60_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 90_00, // 90%
      liqThreshold: 90_50, // 92.5%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 100_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

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
      networkName: 'Plume Mainnet Market',
      networkAbbreviation: 'Plume-Mainnet'
    });
    config.listings = listings;
    config.treasury = 0x614FDB7ad668F90955CE93F9ceF97a3931a05b5D;
    config.interestRateStrategy = 0x0d77c3fD5dCE88b7e17A7D92be3811C1e8de671e;
    config.poolConfigurator = 0xB045411c794273caB6ebc982f1b222A56777582f;
    config.rewardsController = 0x3E0f3B799D0E49B311060fCF3d66Faf45c6E7242;
    config.poolProxy = 0xd5b3495C5e059a23Bea726166E3C46b0Cb3b42Ab;
    config.oracle = 0xC6E0d45573C1F9C3eA63FF3b66CBfF2D64804FB9;
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

// 0xa1a5d0482DEaEFaA43Cd5BA0B513e7dd0b0c20F1 //atoken
//   0xd88a1DCf00e5c959c95dC337Da8D5Bdf5Bdc752e //stoken
//   0x015dFF590BF4c537CBa2f072BCfb2BF8ee7CBA2d // vtoken
//   0xc5f6a9285F9a4D42E6A8b31561a00a66dd36Ce43
//   0xeBf1624c0B248B3Cf2Fad5194799AcF825e4F6b4
//   0x2f73A1121BA291F1D68c509f2040fF9dC0Fef6CE
//   0x8229d69Eb7B6bF1142B6e1E4CC532Be0aFd1B09B
//   0x915AE0d7d5Bd0676bebdf33b9C6182D53E24f820
//   0x2A6F81A76C17A124378180c7a6d1641FF2DB1490
