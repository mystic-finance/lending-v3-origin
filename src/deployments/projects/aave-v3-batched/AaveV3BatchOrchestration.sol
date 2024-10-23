// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {AaveV3TokensBatch} from './batches/AaveV3TokensBatch.sol';
import {AaveV3PoolBatch} from './batches/AaveV3PoolBatch.sol';
import {AaveV3L2PoolBatch} from './batches/AaveV3L2PoolBatch.sol';

import {AaveV3PermissionedPoolBatch} from './batches/AaveV3PermPoolBatch.sol';

import {AaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';

import {AaveV3SemiPermissionedPoolBatch} from './batches/AaveV3SemiPermPoolBatch.sol';

import {AaveV3GettersBatchOne} from './batches/AaveV3GettersBatchOne.sol';
import {AaveV3GettersBatchTwo} from './batches/AaveV3GettersBatchTwo.sol';
import {AaveV3GettersProcedureTwo} from '../../contracts/procedures/AaveV3GettersProcedureTwo.sol';
import {AaveV3PeripheryBatch} from './batches/AaveV3PeripheryBatch.sol';
import {AaveV3ParaswapBatch} from './batches/AaveV3ParaswapBatch.sol';
import {AaveV3SetupBatch} from './batches/AaveV3SetupBatch.sol';
import '../../interfaces/IMarketReportTypes.sol';
import {IMarketReportStorage} from '../../interfaces/IMarketReportStorage.sol';
import {IPoolReport} from '../../interfaces/IPoolReport.sol';

import {TimelockInstance} from 'src/core/instances/TimelockInstance.sol';

import {TimelockController} from 'src/core/contracts/protocol/partner/Timelock.sol';

import {KYCInstance} from 'src/core/instances/KYCInstance.sol';
import {AavePoolWrapper} from 'src/core/contracts/protocol/partner/AavePoolWrapper.sol';

import {PoolAddressesProviderRegistry} from 'src/core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol';

import {ConfigEngineDeployer} from '../../../periphery/contracts/v3-config-engine/ConfigEngineDeployer.sol';

import {PoolAddressesProvider} from 'src/core/contracts/protocol/configuration/PoolAddressesProvider.sol';

import {AaveV3LibrariesBatch1} from '../aave-v3-libraries/AaveV3LibrariesBatch1.sol';

import {AaveV3LibrariesBatch2} from '../aave-v3-libraries/AaveV3LibrariesBatch2.sol';

import {EngineFlags} from 'src/periphery/contracts/v3-config-engine/EngineFlags.sol';
import {IERC20Metadata} from 'lib/solidity-utils/src/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {ReserveConfiguration} from 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {PercentageMath} from 'src/core/contracts/protocol/libraries/math/PercentageMath.sol';
import {MysticPoolVaultFactory} from 'src/core/contracts/protocol/vault/VaultFactory.sol';

/**
 * @title AaveV3BatchOrchestration
 * @author BGD
 * @dev Library which ensemble the deployment of Aave V3 using batch constructor deployment pattern.
 */
library AaveV3BatchOrchestration {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using PercentageMath for uint256;

  function deployAaveV3(
    address deployer,
    Roles memory roles,
    MarketConfig memory config,
    SubMarketConfig memory subConfig,
    DeployFlags memory flags,
    MarketReport memory deployedContracts
  ) internal returns (MarketReport memory) {
    /*
    The following are done here:
    1. pool address provider deployment
    2. pool address provider registry deployment if not found
    3. renouncement of ownership of registry if newly deployed
    4. if pool address provider registry is found from input, then just move on to save report
    */
    (AaveV3SetupBatch setupBatch, InitialReport memory initialReport) = _deploySetupContract(
      deployer,
      roles,
      config,
      deployedContracts
    ); //1

    /*
    The following are done here:
    1. Wallet Balance Provider deployment
    2. UI Incentive deployment
    3. AaveProtocolDataProvider deployment
    4. UiPoolDataProviderV3 deployment needed aggregator proxy
    */
    AaveV3GettersBatchOne.GettersReportBatchOne memory gettersReport1 = _deployGettersBatch1(
      initialReport.poolAddressesProvider,
      config.networkBaseTokenPriceInUsdProxyAggregator,
      config.marketReferenceCurrencyPriceInUsdProxyAggregator
    ); //2

    PoolReport memory poolReport;

    /*
    The following are done here:
    1. Pool Implementation deployment
    2. Pool Configurator deployment
    */
    if (config.poolType == 0) {
      poolReport = _deployPoolImplementations(initialReport.poolAddressesProvider, flags); //3
    } else if (config.poolType == 1) {
      poolReport = _deployPermissionedPoolImplementations(initialReport.poolAddressesProvider); //3
    } else if (config.poolType == 2) {
      poolReport = _deploySemiPermissionedPoolImplementations(initialReport.poolAddressesProvider); //3
    }

    poolReport = _setupKycPortal(subConfig, poolReport, deployer);

    /*
    The following are done here:
    1. Aave Treasury deployment
    2. Aave Incentives deployment - 1. Emission Manager 2. Rewards Controller
    3. Aave Oracle deployment
    4. Aave DRSV2 deployment
    */
    PeripheryReport memory peripheryReport = _deployPeripherals(
      roles,
      config,
      initialReport.poolAddressesProvider,
      address(setupBatch)
    ); //4

    /*
    The following are done here:
    1. Aave Pool Proxy deployment
    2. Aave Rewards Proxy deployment
    3. Aave Protocol Pool Data Proxy deployment
    4. Aave Price Oracle deployment
    5. Aave ACL Manager deployment
    */
    SetupReport memory setupReport = setupBatch.setupAaveV3Market(
      roles,
      config,
      poolReport.poolImplementation,
      poolReport.poolConfiguratorImplementation,
      gettersReport1.protocolDataProvider,
      peripheryReport.aaveOracle,
      peripheryReport.rewardsControllerImplementation,
      poolReport.kycPortal
    ); //5

    // ParaswapReport memory paraswapReport = _deployParaswapAdapters(
    //   roles,
    //   config,
    //   initialReport.poolAddressesProvider,
    //   peripheryReport.treasury
    // ); //8

    /*
    The following are done here:
    1. Wrapped token gateway deployment
    2. L2 Encoder deployment
    */
    AaveV3GettersBatchTwo.GettersReportBatchTwo memory gettersReport2 = _deployGettersBatch2(
      setupReport.poolProxy,
      roles.poolAdmin,
      config.wrappedNativeToken,
      flags.l2
    ); // 6

    /*
    The following are done here:
    1. AToken deployment
    2. VToken deployment
    3. SToken deployment
    */
    AaveV3TokensBatch.TokensReport memory tokensReport = _deployTokens(
      setupReport.poolProxy,
      peripheryReport.treasury,
      subConfig
    ); // 7

    // list reserve

    // Save final report at AaveV3SetupBatch contract
    MarketReport memory report = _generateMarketReport(
      initialReport,
      gettersReport1,
      gettersReport2,
      poolReport,
      peripheryReport,
      // paraswapReport,
      setupReport,
      tokensReport
    ); // 9

    /*
    The following are done here:
    1. Enginer deployment (deprecated)
    */
    // address engine = _deployEngine(report, subConfig);

    // report.engine = engine;

    setupBatch.setMarketReport(report);

    return report;
  }

  function deployUIPoolDatProvider(
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) internal returns (address) {
    return
      _deployUIPoolDataProvider(
        networkBaseTokenPriceInUsdProxyAggregator,
        marketReferenceCurrencyPriceInUsdProxyAggregator
      );
  }

  function updateProviderRegistry(
    address poolAddressesProviderRegistry,
    address poolAddressesProvider,
    uint providerId
  ) internal returns (bool) {
    address owner = PoolAddressesProviderRegistry(poolAddressesProviderRegistry).owner();
    PoolAddressesProviderRegistry(poolAddressesProviderRegistry).registerAddressesProvider(
      poolAddressesProvider,
      providerId
    );
    return true;
  }

  function listAssetPairAaveV3(
    ListingConfig memory config,
    SubMarketConfig memory subConfig
  ) internal {
    IPoolConfigurator configurator = IPoolConfigurator(config.poolConfigurator);

    // 1. set price feeds
    _setPriceFeeds(IAaveOracle(config.oracle), config);

    // configurator.dropReserve(config.listings[0].asset);
    // configurator.dropReserve(config.listings[1].asset);

    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](
        config.listings.length
      );

    // 2. in a loop do the reserved configuration
    for (uint256 i = 0; i < config.listings.length; i++) {
      uint8 decimals = IERC20Metadata(config.listings[i].asset).decimals();
      require(decimals > 0, 'INVALID_ASSET_DECIMALS');

      // 3. set the underlying and debt asset to be asser for atoken and stoken generation, to allow switching of debt asset and supply assets
      subConfig.underlyingAsset = config.listings[i].asset;
      subConfig.debtAsset = config.listings[i].asset;

      // 4. deploy all tokens
      AaveV3TokensBatch.TokensReport memory tokensReport = _deployTokens(
        config.poolProxy,
        config.treasury,
        subConfig
      );

      console.log(tokensReport.aToken);
      console.log(tokensReport.stableDebtToken);
      console.log(tokensReport.variableDebtToken);

      // 5. initialize reserve for each asset
      initReserveInputs[i] = ConfiguratorInputTypes.InitReserveInput({
        aTokenImpl: tokensReport.aToken,
        stableDebtTokenImpl: tokensReport.stableDebtToken,
        variableDebtTokenImpl: tokensReport.variableDebtToken,
        underlyingAssetDecimals: decimals,
        interestRateStrategyAddress: config.interestRateStrategy,
        interestRateData: abi.encode(config.listings[i].rateStrategyParams),
        underlyingAsset: config.listings[i].asset,
        treasury: config.treasury,
        incentivesController: config.rewardsController,
        useVirtualBalance: true,
        aTokenName: string.concat(
          'Mystic ',
          config.poolContext.networkName,
          ' ',
          config.listings[i].assetSymbol
        ),
        aTokenSymbol: string.concat(
          'my',
          config.poolContext.networkAbbreviation,
          config.listings[i].assetSymbol
        ),
        variableDebtTokenName: string.concat(
          'Mystic ',
          config.poolContext.networkName,
          ' Variable Debt ',
          config.listings[i].assetSymbol
        ),
        variableDebtTokenSymbol: string.concat(
          'my-V',
          config.poolContext.networkAbbreviation,
          config.listings[i].assetSymbol
        ),
        stableDebtTokenName: string.concat(
          'Mystic ',
          config.poolContext.networkName,
          ' Stable Debt ',
          config.listings[i].assetSymbol
        ),
        stableDebtTokenSymbol: string.concat(
          'my-S',
          config.poolContext.networkAbbreviation,
          config.listings[i].assetSymbol
        ),
        params: bytes('')
      });
    }
    configurator.initReserves(initReserveInputs);

    // 6. configure caps, borrow side, collateral and assets emode
    for (uint256 i = 0; i < config.listings.length; i++) {
      _configureCaps(configurator, config.listings[i]);
      _configBorrowSide(configurator, config.listings[i], IPool(config.poolProxy));
      _configCollateralSide(configurator, config.listings[i], IPool(config.poolProxy));
      _configAssetsEMode(configurator, config.listings[i]);
    }
  }

  function updateAssetPairAaveV3(
    ListingConfig memory config,
    SubMarketConfig memory subConfig
  ) internal {
    IPoolConfigurator configurator = IPoolConfigurator(config.poolConfigurator);
    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](
        config.listings.length
      );

    // 6. configure caps, borrow side, collateral and assets emode
    for (uint256 i = 0; i < config.listings.length; i++) {
      _configureCaps(configurator, config.listings[i]);
      _configBorrowSide(configurator, config.listings[i], IPool(config.poolProxy));
      _configCollateralSide(configurator, config.listings[i], IPool(config.poolProxy));
      _configAssetsEMode(configurator, config.listings[i]);
    }
  }

  function deployAaveBundler(
    address pointsProgram,
    uint8 taskId
  ) internal returns (address bundler) {
    bundler = address(new AavePoolWrapper(pointsProgram, taskId));
    return (bundler);
  }

  function deployAaveVaultFactory() internal returns (address aaveVaultFactory) {
    aaveVaultFactory = address(new MysticPoolVaultFactory());
  }

  function deployAaveVault(
    address vaultFactory,
    uint256 initialTimelock,
    address asset,
    uint256 maxDeposit,
    uint256 maxWithdrawal,
    uint256 fee,
    address feeRecipient,
    string memory name,
    string memory symbol,
    bytes32 salt
  ) internal returns (address aaveVault) {
    MysticPoolVaultFactory aaveVaultFactory = MysticPoolVaultFactory(vaultFactory);
    aaveVault = address(
      aaveVaultFactory.createVault(
        initialTimelock,
        asset,
        maxDeposit,
        maxWithdrawal,
        fee,
        feeRecipient,
        name,
        symbol,
        salt
      )
    );
  }

  function updateAaveBundlerPointProgram(
    address pointsProgram,
    address _wrapper
  ) internal returns (address wrapper) {
    AavePoolWrapper bundler = AavePoolWrapper(_wrapper);
    bundler.updatePointProgram(pointsProgram);
    return address(bundler);
  }

  function testAaveBundler(
    address pool,
    address _wrapper,
    address token,
    uint amount
  ) internal returns (address bundler) {
    AavePoolWrapper wrapper = AavePoolWrapper(_wrapper);
    IERC20(token).approve(address(wrapper), amount);
    wrapper.supply(pool, token, amount);
  }

  function _deploySetupContract(
    address deployer,
    Roles memory roles,
    MarketConfig memory config,
    MarketReport memory deployedContracts
  ) internal returns (AaveV3SetupBatch, InitialReport memory) {
    AaveV3SetupBatch setupBatch = new AaveV3SetupBatch(deployer, roles, config, deployedContracts);
    return (setupBatch, setupBatch.getInitialReport());
  }

  function _deployUIPoolDataProvider(
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) internal returns (address) {
    address poolDataProvider = address(
      new UiPoolDataProviderV3(
        IEACAggregatorProxy(networkBaseTokenPriceInUsdProxyAggregator),
        IEACAggregatorProxy(marketReferenceCurrencyPriceInUsdProxyAggregator)
      )
    );

    return poolDataProvider;
  }

  function _deployGettersBatch1(
    address poolAddressesProvider,
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) internal returns (AaveV3GettersBatchOne.GettersReportBatchOne memory) {
    AaveV3GettersBatchOne gettersBatch1 = new AaveV3GettersBatchOne(
      poolAddressesProvider,
      networkBaseTokenPriceInUsdProxyAggregator,
      marketReferenceCurrencyPriceInUsdProxyAggregator
    );

    return gettersBatch1.getGettersReportOne();
  }

  function _deployGettersBatch2(
    address poolProxy,
    address poolAdmin,
    address wrappedNativeToken,
    bool l2Flag
  ) internal returns (AaveV3GettersBatchTwo.GettersReportBatchTwo memory) {
    AaveV3GettersBatchTwo gettersBatch2;
    if (wrappedNativeToken != address(0) || l2Flag) {
      gettersBatch2 = new AaveV3GettersBatchTwo(poolProxy, poolAdmin, wrappedNativeToken, l2Flag);
      return gettersBatch2.getGettersReportTwo();
    }

    return
      AaveV3GettersProcedureTwo.GettersReportBatchTwo({
        wrappedTokenGateway: address(0),
        l2Encoder: address(0)
      });
  }

  function _deployPoolImplementations(
    address poolAddressesProvider,
    DeployFlags memory flags
  ) internal returns (PoolReport memory) {
    IPoolReport poolBatch;

    if (flags.l2) {
      poolBatch = IPoolReport(new AaveV3L2PoolBatch(poolAddressesProvider)); // 3-1
    } else {
      poolBatch = IPoolReport(new AaveV3PoolBatch(poolAddressesProvider));
    }

    return poolBatch.getPoolReport();
  }

  function _deployPermissionedPoolImplementations(
    address poolAddressesProvider
  ) internal returns (PoolReport memory) {
    IPoolReport poolBatch;

    poolBatch = IPoolReport(new AaveV3PermissionedPoolBatch(poolAddressesProvider)); // 3-1

    return poolBatch.getPoolReport();
  }

  function _deploySemiPermissionedPoolImplementations(
    address poolAddressesProvider
  ) internal returns (PoolReport memory) {
    IPoolReport poolBatch;

    poolBatch = IPoolReport(new AaveV3SemiPermissionedPoolBatch(poolAddressesProvider)); // 3-1

    return poolBatch.getPoolReport();
  }

  function _deployTimelock(address admin) internal returns (address) {
    address[] memory executors = new address[](2);
    executors[0] = admin;
    executors[1] = msg.sender;
    TimelockController timelock = new TimelockController(20 minutes, executors, executors, admin);

    return address(timelock);
  }

  function _deployKycPortal(address timelock) internal returns (address) {
    address kycPortal = address(new KYCInstance(timelock));

    return kycPortal;
  }

  function _deployPeripherals(
    Roles memory roles,
    MarketConfig memory config,
    address poolAddressesProvider,
    address setupBatch
  ) internal returns (PeripheryReport memory) {
    AaveV3PeripheryBatch peripheryBatch = new AaveV3PeripheryBatch(
      roles.poolAdmin,
      config,
      poolAddressesProvider,
      setupBatch
    );

    return peripheryBatch.getPeripheryReport();
  }

  // function _deployParaswapAdapters(
  //   Roles memory roles,
  //   MarketConfig memory config,
  //   address poolAddressesProvider,
  //   address treasury
  // ) internal returns (ParaswapReport memory) {
  //   if (config.paraswapAugustusRegistry != address(0) && config.paraswapFeeClaimer != address(0)) {
  //     AaveV3ParaswapBatch parawswapBatch = new AaveV3ParaswapBatch(
  //       roles.poolAdmin,
  //       config,
  //       poolAddressesProvider,
  //       treasury
  //     );
  //     return parawswapBatch.getParaswapReport();
  //   }

  //   return
  //     ParaswapReport({
  //       paraSwapLiquiditySwapAdapter: address(0),
  //       paraSwapRepayAdapter: address(0),
  //       paraSwapWithdrawSwapAdapter: address(0),
  //       aaveParaSwapFeeClaimer: address(0)
  //     });
  // }

  function _deployTokens(
    address poolProxy,
    address treasury,
    SubMarketConfig memory subConfig
  ) internal returns (AaveV3TokensBatch.TokensReport memory) {
    AaveV3TokensBatch tokensBatch = new AaveV3TokensBatch(
      poolProxy,
      treasury,
      subConfig.underlyingAsset,
      subConfig.debtAsset
    );

    return tokensBatch.getTokensReport();
  }

  function _deployEngine(
    MarketReport memory report,
    SubMarketConfig memory subConfig
  ) internal returns (address) {
    address engine = ConfigEngineDeployer.deployEngine(report, subConfig.create2_factory);
    return engine;
  }

  function _setPriceFeeds(IAaveOracle oracle, ListingConfig memory config) internal {
    address[] memory assets = new address[](config.listings.length);
    address[] memory sources = new address[](config.listings.length);

    for (uint256 i = 0; i < config.listings.length; i++) {
      require(config.listings[i].priceFeed != address(0), 'PRICE_FEED_ALWAYS_REQUIRED');
      require(
        IEACAggregatorProxy(config.listings[i].priceFeed).latestAnswer() > 0,
        'FEED_SHOULD_RETURN_POSITIVE_PRICE'
      );
      assets[i] = config.listings[i].asset;
      sources[i] = config.listings[i].priceFeed;
    }

    oracle.setAssetSources(assets, sources);
  }

  function _configureCaps(
    IPoolConfigurator poolConfigurator,
    IAaveV3ConfigEngine.Listing memory listing
  ) internal {
    if (listing.supplyCap != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setSupplyCap(listing.asset, listing.supplyCap);
    }

    if (listing.borrowCap != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setBorrowCap(listing.asset, listing.borrowCap);
    }
  }

  function _configAssetsEMode(
    IPoolConfigurator poolConfigurator,
    IAaveV3ConfigEngine.Listing memory listing
  ) internal {
    if (listing.eModeCategory != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setAssetEModeCategory(listing.asset, listing.eModeCategory);
    }
  }

  function _setupKycPortal(
    SubMarketConfig memory subConfig,
    PoolReport memory poolReport,
    address deployer
  ) internal returns (PoolReport memory) {
    /*
    The following are done here:
    1. Timelock deployment
    2. KYCPortal deployment
    */
    {
      if (subConfig.timelock == address(0)) {
        subConfig.timelock = _deployTimelock(deployer);
      }

      if (subConfig.kycPortal == address(0)) {
        subConfig.kycPortal = _deployKycPortal(subConfig.timelock);
      }
    }

    poolReport.kycPortal = subConfig.kycPortal;
    poolReport.timelock = subConfig.timelock;

    return poolReport;
  }

  function _configBorrowSide(
    IPoolConfigurator poolConfigurator,
    IAaveV3ConfigEngine.Listing memory listing,
    IPool pool
  ) internal {
    if (listing.enabledToBorrow != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setReserveBorrowing(
        listing.asset,
        EngineFlags.toBool(listing.enabledToBorrow)
      );
    } else {
      (, , bool borrowingEnabled, , ) = pool.getConfiguration(listing.asset).getFlags();
      listing.enabledToBorrow = EngineFlags.fromBool(borrowingEnabled);
    }

    if (listing.enabledToBorrow == EngineFlags.ENABLED) {
      if (listing.stableRateModeEnabled != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setReserveStableRateBorrowing(
          listing.asset,
          EngineFlags.toBool(listing.stableRateModeEnabled)
        );
      }
    }

    if (listing.borrowableInIsolation != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setBorrowableInIsolation(
        listing.asset,
        EngineFlags.toBool(listing.borrowableInIsolation)
      );
    }

    if (listing.withSiloedBorrowing != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setSiloedBorrowing(
        listing.asset,
        EngineFlags.toBool(listing.withSiloedBorrowing)
      );
    }

    // The reserve factor should always be > 0
    require(
      (listing.reserveFactor > 0 && listing.reserveFactor <= 100_00) ||
        listing.reserveFactor == EngineFlags.KEEP_CURRENT,
      'INVALID_RESERVE_FACTOR'
    );

    if (listing.reserveFactor != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setReserveFactor(listing.asset, listing.reserveFactor);
    }

    if (listing.flashloanable != EngineFlags.KEEP_CURRENT) {
      poolConfigurator.setReserveFlashLoaning(
        listing.asset,
        EngineFlags.toBool(listing.flashloanable)
      );
    }
  }

  function _configCollateralSide(
    IPoolConfigurator poolConfigurator,
    IAaveV3ConfigEngine.Listing memory listing,
    IPool pool
  ) internal {
    if (listing.liqThreshold != 0) {
      bool notAllKeepCurrent = listing.ltv != EngineFlags.KEEP_CURRENT ||
        listing.liqThreshold != EngineFlags.KEEP_CURRENT ||
        listing.liqBonus != EngineFlags.KEEP_CURRENT;

      bool atLeastOneKeepCurrent = listing.ltv == EngineFlags.KEEP_CURRENT ||
        listing.liqThreshold == EngineFlags.KEEP_CURRENT ||
        listing.liqBonus == EngineFlags.KEEP_CURRENT;

      if (notAllKeepCurrent && atLeastOneKeepCurrent) {
        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(
          listing.asset
        );
        (
          uint256 currentLtv,
          uint256 currentLiqThreshold,
          uint256 currentLiqBonus,
          ,
          ,

        ) = configuration.getParams();

        if (listing.ltv == EngineFlags.KEEP_CURRENT) {
          listing.ltv = currentLtv;
        }

        if (listing.liqThreshold == EngineFlags.KEEP_CURRENT) {
          listing.liqThreshold = currentLiqThreshold;
        }

        if (listing.liqBonus == EngineFlags.KEEP_CURRENT) {
          // Subtracting 100_00 to be consistent with the engine as 100_00 gets added while setting the liqBonus
          listing.liqBonus = currentLiqBonus - 100_00;
        }
      }

      if (notAllKeepCurrent) {
        // LT*LB (in %) should never be above 100%, because it means instant undercollateralization
        require(
          listing.liqThreshold.percentMul(100_00 + listing.liqBonus) <= 100_00,
          'INVALID_LT_LB_RATIO'
        );

        poolConfigurator.configureReserveAsCollateral(
          listing.asset,
          listing.ltv,
          listing.liqThreshold,
          // For reference, this is to simplify the interaction with the Aave protocol,
          // as there the definition is as e.g. 105% (5% bonus for liquidators)
          100_00 + listing.liqBonus
        );
      }

      if (listing.liqProtocolFee != EngineFlags.KEEP_CURRENT) {
        require(listing.liqProtocolFee < 100_00, 'INVALID_LIQ_PROTOCOL_FEE');
        poolConfigurator.setLiquidationProtocolFee(listing.asset, listing.liqProtocolFee);
      }

      if (listing.debtCeiling != EngineFlags.KEEP_CURRENT) {
        // For reference, this is to simplify the interactions with the Aave protocol,
        // as there the definition is with 2 decimals. We don't see any reason to set
        // a debt ceiling involving .something USD, so we simply don't allow to do it
        poolConfigurator.setDebtCeiling(listing.asset, listing.debtCeiling * 100);
      }
    }
  }

  function _generateMarketReport(
    InitialReport memory initialReport,
    AaveV3GettersBatchOne.GettersReportBatchOne memory gettersReportOne,
    AaveV3GettersBatchTwo.GettersReportBatchTwo memory gettersReportTwo,
    PoolReport memory poolReport,
    PeripheryReport memory peripheryReport,
    // ParaswapReport memory paraswapReport,
    SetupReport memory setupReport,
    AaveV3TokensBatch.TokensReport memory tokensReport
  ) internal pure returns (MarketReport memory) {
    MarketReport memory report;

    report.poolAddressesProvider = initialReport.poolAddressesProvider;
    report.poolAddressesProviderRegistry = initialReport.poolAddressesProviderRegistry;
    report.emissionManager = peripheryReport.emissionManager;
    report.rewardsControllerImplementation = peripheryReport.rewardsControllerImplementation;
    report.walletBalanceProvider = gettersReportOne.walletBalanceProvider;
    report.uiIncentiveDataProvider = gettersReportOne.uiIncentiveDataProvider;
    report.protocolDataProvider = gettersReportOne.protocolDataProvider;
    report.uiPoolDataProvider = gettersReportOne.uiPoolDataProvider;
    report.poolImplementation = poolReport.poolImplementation;
    report.wrappedTokenGateway = gettersReportTwo.wrappedTokenGateway;
    report.l2Encoder = gettersReportTwo.l2Encoder;
    report.poolConfiguratorImplementation = poolReport.poolConfiguratorImplementation;
    report.aaveOracle = peripheryReport.aaveOracle;
    // report.paraSwapLiquiditySwapAdapter = paraswapReport.paraSwapLiquiditySwapAdapter;
    // report.paraSwapRepayAdapter = paraswapReport.paraSwapRepayAdapter;
    // report.paraSwapWithdrawSwapAdapter = paraswapReport.paraSwapWithdrawSwapAdapter;
    // report.aaveParaSwapFeeClaimer = paraswapReport.aaveParaSwapFeeClaimer;
    report.treasuryImplementation = peripheryReport.treasuryImplementation;
    report.proxyAdmin = peripheryReport.proxyAdmin;
    report.treasury = peripheryReport.treasury;
    report.poolProxy = setupReport.poolProxy;
    report.poolConfiguratorProxy = setupReport.poolConfiguratorProxy;
    report.rewardsControllerProxy = setupReport.rewardsControllerProxy;
    report.aclManager = setupReport.aclManager;
    report.aToken = tokensReport.aToken;
    report.variableDebtToken = tokensReport.variableDebtToken;
    report.stableDebtToken = tokensReport.stableDebtToken;
    report.defaultInterestRateStrategyV2 = peripheryReport.defaultInterestRateStrategyV2;
    report.kycPortal = poolReport.kycPortal;
    report.timelock = poolReport.timelock;

    return report;
  }
}
