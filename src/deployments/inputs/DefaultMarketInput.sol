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

    config.marketId = 'Aave V3 Mystic Polygon Testnet Market';
    config.providerId = 8084;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config
      .marketReferenceCurrencyPriceInUsdProxyAggregator = 0x59AB56F7285e723CD417aFf63EEea800fD037995;
    config.networkBaseTokenPriceInUsdProxyAggregator = 0x59AB56F7285e723CD417aFf63EEea800fD037995;
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
      asset: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
      assetSymbol: 'ETH',
      priceFeed: 0x59AB56F7285e723CD417aFf63EEea800fD037995,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_50, // 1%
        variableRateSlope1: 10_00,
        variableRateSlope2: 75_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 88_00, // 90%
      liqThreshold: 88_50, // 92.5%
      liqBonus: 10_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
      assetSymbol: 'WBTC',
      priceFeed: 0x830ED9E3461667BAE2765131Ae784dd307a24fBF,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_25, // 1.25%
        variableRateSlope1: 10_00,
        variableRateSlope2: 70_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.ENABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.ENABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 87_50, // 87.5%
      liqThreshold: 88_00, // 90%
      liqBonus: 10_00, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_000, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    config.poolContext = IAaveV3ConfigEngine.PoolContext({
      networkName: 'Polygon mainner',
      networkAbbreviation: 'Polygon'
    });
    config.listings = listings;
    config.treasury = 0x1B7cbcA30a2c224E4ced24ccB33592424eE97178;
    config.interestRateStrategy = 0xa7d5A175F3eD04f885d14139E67e850863F7f199;
    config.poolConfigurator = 0x12742Ef8dc6F2876F5CcDa70Fbac9574AAE2658c;
    config.rewardsController = 0x626Cc646271B8FaB6e32485028c2FDC2D70522D5;
    config.poolProxy = 0x9fEae4675b90f336328AAbeC5253C707129eEB86;
    config.oracle = 0x1033Ca0E2F5b58a753672EC88da7A512d5A8Cdee;
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
