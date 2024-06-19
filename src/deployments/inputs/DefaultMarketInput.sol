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

    config.marketId = 'Aave V3 Mystic Plume DAI/WETH Testnet Market';
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
      asset: 0x1aa70741167155E08bD319bE096C94eE54C6CA19,
      assetSymbol: 'DAI',
      priceFeed: 0x34d75eB977F06A53362900D3F09F7eDEe324aFe8,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 55, // 0.25%
        variableRateSlope1: 4_00,
        variableRateSlope2: 75_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 70.5%
      liqThreshold: 0, // 76%
      liqBonus: 12_50, // 5%
      reserveFactor: 15_00, // 10%
      supplyCap: 50_000_000_000, // 100k AAVE
      borrowCap: 50_000_000_00, // 60k AAVE
      debtCeiling: 0, // 100k USD
      liqProtocolFee: 10_00, // 10%
      eModeCategory: 0 // No category
    });

    listings[1] = IAaveV3ConfigEngine.Listing({
      //collateral
      asset: 0x99835d80000f6998015AdA61fb88f6F94F3759fe,
      assetSymbol: 'WETH',
      priceFeed: 0x32c3Be69BeB6628EBBbF2A826D862d68e77DBDc9,
      rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 55, // 0.25%
        variableRateSlope1: 3_00,
        variableRateSlope2: 60_00
      }),
      enabledToBorrow: EngineFlags.DISABLED,
      flashloanable: EngineFlags.DISABLED,
      stableRateModeEnabled: EngineFlags.DISABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      ltv: 80_00, // 70.5%
      liqThreshold: 80_50, // 76%
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
    config.treasury = 0x7aeA9A52931fA4Bd617649967F4C45Be6268Fa8b;
    config.interestRateStrategy = 0xcf777BFc1f614f2a1d5E28A63D50FdEa884415A7;
    config.poolConfigurator = 0x28b5568427d2b93082C38c409A6769BCE3b04B52;
    config.rewardsController = 0xCc794eEAfDC31F340CB5Eb2f58E33F0dA20dAeFD;
    config.poolProxy = 0xeb2f0301f2275aaC4fD96C278a255Dd3F62F53b1;
    config.oracle = 0xC54df95BC7956E2D18b324b9173ba20Ce635EA81;
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
