// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {IAaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'src/periphery/contracts/v3-config-engine/EngineFlags.sol';

contract DefaultMarketInput is MarketInput {
  address debtAsset = 0xbC47901f4d2C5fc871ae0037Ea05c3F614690781;
  address collateralAsset = 0xbC47901f4d2C5fc871ae0037Ea05c3F614690781;

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

    config.marketId = 'Aave V3 Mystic USDA/stWETH Testnet Market';
    config.providerId = 8080;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 1;
    config.marketReferenceCurrencyPriceInUsdProxyAggregator = address(0);
    config.networkBaseTokenPriceInUsdProxyAggregator = address(0);
    config.wrappedNativeToken = address(0);

    subConfig.timelock = address(0);
    subConfig.kycPortal = address(0);
    subConfig.underlyingAsset = collateralAsset;
    subConfig.debtAsset = debtAsset;

    deployedContracts.poolAddressesProviderRegistry = address(0);
    flags.l2 = true;

    return (roles, config, subConfig, flags, deployedContracts);
  }

  function _listAsset(
    address deployer
  ) internal view override returns (ListingConfig memory config) {
    IAaveV3ConfigEngine.Listing[] memory listingBorrow = new IAaveV3ConfigEngine.Listing[](1);
    IAaveV3ConfigEngine.Listing[] memory listingCollateral = new IAaveV3ConfigEngine.Listing[](1);

    listingBorrow[0] = IAaveV3ConfigEngine.Listing({ //borrow asset
      asset: debtAsset,
      assetSymbol: 'USDC',
      priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 25, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 75_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 75_00, // 70.5%
      liqThreshold: 0, // 0%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 100_000_000, // 60k AAVE
      debtCeiling: 10_000_000, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listingCollateral[0] = IAaveV3ConfigEngine.Listing({ //collateral
      asset: collateralAsset,
      assetSymbol: 'stETH',
      priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 25, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 75_00
      }),
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 75_00, // 70.5%
      liqThreshold: 77_50, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 0, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    config.poolContext = IAaveV3ConfigEngine.PoolContext({
      networkName: 'Arbitrum Sepolia',
      networkAbbreviation: 'Arb-Sep'
    });
    config.listingBorrow = listingBorrow;
    config.listingCollateral = listingCollateral;
    // USDC/stETH pool == borrow/collateral

    return (config);
  }

  function _updateCollateral(
    address deployer
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
    address deployer
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
