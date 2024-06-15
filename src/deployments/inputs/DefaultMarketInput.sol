// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';
import {IAaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'src/periphery/contracts/v3-config-engine/EngineFlags.sol';

contract DefaultMarketInput is MarketInput {
  // address debtAsset = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1; //usdc
  // address collateralAsset = 0xc708ff370fC21D3E48849B56a167a1c91A1D48D0; //rwa token (test is usdt)

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

    config.marketId = 'Aave V3 Mystic Plume USDC/Landshare Testnet Market';
    config.providerId = 8080;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;
    config.poolType = 0;
    config.marketReferenceCurrencyPriceInUsdProxyAggregator = address(0);
    config.networkBaseTokenPriceInUsdProxyAggregator = address(0);
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

    listings[0] = IAaveV3ConfigEngine.Listing({ //borrow asset
      asset: debtAsset,
      assetSymbol: 'USDC',
      priceFeed: 0xC3235610cd9930DCeF1728d2DCfC25a0D419232C,
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
      ltv: 90_00, // 70.5%
      liqThreshold: 0, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 100_000_000, // 60k AAVE
      debtCeiling: 10_000_000, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({ //collateral
      asset: collateralAsset,
      assetSymbol: 'LandShare',
      priceFeed: 0xC3235610cd9930DCeF1728d2DCfC25a0D419232C,
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
      ltv: 90_00, // 70.5%
      liqThreshold: 90_50, // 76%
      liqBonus: 5_00, // 5%
      reserveFactor: 10_00, // 10%
      supplyCap: 100_000_000, // 100k AAVE
      borrowCap: 10, // 60k AAVE
      debtCeiling: 10_000_000, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    config.poolContext = IAaveV3ConfigEngine.PoolContext({
      networkName: 'Arbitrum Sepolia',
      networkAbbreviation: 'Arb-Sep'
    });
    config.listings = listings;
    config.treasury = 0x3F36849c1f7Fc7a58A503604790D457ab8bB8062;
    config.interestRateStrategy = 0xd7E9886c895a307F58b14B70F2cd8bC3ef0C6650;
    config.poolConfigurator = 0x10BF67A7f42FBbcB6f5C4302f33Cd3Ef17af095b;
    config.rewardsController = 0xDb1a70f828679e342b2AB9b62E4C2a29fcC37957;
    config.poolProxy = 0xb8b46BDC1B85E0d22d61218e750b2BbAE0fA5e45;
    config.oracle = 0xCB594bE528eb3D06bd14D7Edf83F13695e7c5448;
    // config.listingCollateral = listingCollateral;
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
