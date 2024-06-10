// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
import {ConfigEngineDeployer} from '../../../periphery/contracts/v3-config-engine/ConfigEngineDeployer.sol';

import {AaveV3LibrariesBatch1} from '../aave-v3-libraries/AaveV3LibrariesBatch1.sol';

import {AaveV3LibrariesBatch2} from '../aave-v3-libraries/AaveV3LibrariesBatch2.sol';

/**
 * @title AaveV3BatchOrchestration
 * @author BGD
 * @dev Library which ensemble the deployment of Aave V3 using batch constructor deployment pattern.
 */
library AaveV3BatchOrchestration {
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

    poolReport.kycPortal = subConfig.kycPortal;
    poolReport.timelock = subConfig.timelock;

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
      peripheryReport.rewardsControllerImplementation
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
    1. Enginer deployment
    */
    address engine = _deployEngine(report, subConfig);

    report.engine = engine;

    setupBatch.setMarketReport(report);

    return report;
  }

  function listAssetPairAaveV3(
    address deployer,
    ListingConfig memory config,
    MarketReport memory deployedContracts
  ) internal returns (MarketReport memory) {
    AaveV3ConfigEngine engine = AaveV3ConfigEngine(deployedContracts.engine);
    engine.listAssets(config.poolContext, config.listingBorrow);
    engine.listAssets(config.poolContext, config.listingCollateral);

    return deployedContracts;
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
