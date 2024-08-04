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

    config.marketId = 'Aave V3 Mystic Plume gnUSD/GOON Testnet Market';
    config.providerId = 8081;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x34d75eB977F06A53362900D3F09F7eDEe324aFe8;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x34d75eB977F06A53362900D3F09F7eDEe324aFe8;
    config.wrappedNativeToken = address(0);

    subConfig.timelock = 0x42eF942275605a0d8dF85cAc7e1Ead0c8dA2346F; //address(0);
    subConfig.kycPortal = 0xA85206d14d5C0fC88D60dFAED7d7891f99f700c3; //address(0);
    subConfig.underlyingAsset = address(0);
    subConfig.debtAsset = address(0);
    subConfig.create2_factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C; //0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    deployedContracts.poolAddressesProviderRegistry = 0x1A1d9065b4d705484706ADc2D7a147d128a34296; //address(0);
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
      asset: 0x5c1409a46cD113b3A667Db6dF0a8D7bE37ed3BB3,
      assetSymbol: 'gnUSD',
      priceFeed: 0x34d75eB977F06A53362900D3F09F7eDEe324aFe8,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_00, // 0.25%
        variableRateSlope1: 4_00,
        variableRateSlope2: 75_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 85_00, // 70.5%
      liqThreshold: 0, // 76%
      liqBonus: 12_50, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0xbA22114ec75f0D55C34A5E5A3cf384484Ad9e733,
      assetSymbol: 'GOON',
      priceFeed: 0x71734ab801Ee8a215c003F09047bfd8e0419A953,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 55, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 85_00, // 70.5%
      liqThreshold: 85_50, // 76%
      liqBonus: 10_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 10, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    config.poolContext = IAaveV3ConfigEngine.PoolContext({
      networkName: 'Plume Testnet',
      networkAbbreviation: 'Plume'
    });
    config.listings = listings;
    config.treasury = 0x1CeA8B4007C50C926B88fEd9a521fAafB5fE2a2B;
    config.interestRateStrategy = 0xC49c6327cedfa4bD2ca3a7cC5487AFd66aB157d6;
    config.poolConfigurator = 0xb1E1A3318b1195d2ECD937897e4a4E1cc285Fad2;
    config.rewardsController = 0xA12926f249E68C95DDC9E6D7c7Eaa83F0c853B62;
    config.poolProxy = 0xE55bb0aECBE4ae6BD9643818E4E04183980ef98A;
    config.oracle = 0xac6DFA76713EdbAf779DF45960ECe500533f6b52;
    // USDC/USDT pool == borrow/collateral

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
