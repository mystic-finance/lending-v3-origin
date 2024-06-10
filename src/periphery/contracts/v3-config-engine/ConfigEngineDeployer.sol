// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '../../../deployments/interfaces/IMarketReportTypes.sol';
import {Create2Utils} from '../../../deployments/contracts/utilities/Create2Utils.sol';
import {AaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {IAaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IPoolAddressesProvider} from '../../../core/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from '../../../core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from '../../../core/contracts/interfaces/IPoolConfigurator.sol';
import {IAaveOracle} from '../../../core/contracts/interfaces/IAaveOracle.sol';
import {CapsEngine} from 'src/periphery/contracts/v3-config-engine/libraries/CapsEngine.sol';
import {BorrowEngine} from 'src/periphery/contracts/v3-config-engine/libraries/BorrowEngine.sol';
import {CollateralEngine} from 'src/periphery/contracts/v3-config-engine/libraries/CollateralEngine.sol';
import {RateEngine} from 'src/periphery/contracts/v3-config-engine/libraries/RateEngine.sol';
import {PriceFeedEngine} from 'src/periphery/contracts/v3-config-engine/libraries/PriceFeedEngine.sol';
import {EModeEngine} from 'src/periphery/contracts/v3-config-engine/libraries/EModeEngine.sol';
import {ListingEngine} from 'src/periphery/contracts/v3-config-engine/libraries/ListingEngine.sol';

library ConfigEngineDeployer {
  function deployEngine(MarketReport memory report, address factory) internal returns (address) {
    IAaveV3ConfigEngine.EngineLibraries memory engineLibraries = IAaveV3ConfigEngine
      .EngineLibraries({
        listingEngine: Create2Utils._create2Deploy('v1', type(ListingEngine).creationCode, factory),
        eModeEngine: Create2Utils._create2Deploy('v1', type(EModeEngine).creationCode, factory),
        borrowEngine: Create2Utils._create2Deploy('v1', type(BorrowEngine).creationCode, factory),
        collateralEngine: Create2Utils._create2Deploy(
          'v1',
          type(CollateralEngine).creationCode,
          factory
        ),
        priceFeedEngine: Create2Utils._create2Deploy(
          'v1',
          type(PriceFeedEngine).creationCode,
          factory
        ),
        rateEngine: Create2Utils._create2Deploy('v1', type(RateEngine).creationCode, factory),
        capsEngine: Create2Utils._create2Deploy('v1', type(CapsEngine).creationCode, factory)
      });

    IAaveV3ConfigEngine.EngineConstants memory engineConstants = IAaveV3ConfigEngine
      .EngineConstants({
        pool: IPool(report.poolProxy),
        poolConfigurator: IPoolConfigurator(report.poolConfiguratorProxy),
        defaultInterestRateStrategy: report.defaultInterestRateStrategyV2,
        oracle: IAaveOracle(report.aaveOracle),
        rewardsController: report.rewardsControllerProxy,
        collector: report.treasury
      });

    return
      address(
        new AaveV3ConfigEngine(
          report.aToken,
          report.variableDebtToken,
          report.stableDebtToken,
          engineConstants,
          engineLibraries
        )
      );
  }

  function deployEngine(MarketReport memory report) internal returns (address) {
    IAaveV3ConfigEngine.EngineLibraries memory engineLibraries = IAaveV3ConfigEngine
      .EngineLibraries({
        listingEngine: Create2Utils._create2Deploy('v1', type(ListingEngine).creationCode),
        eModeEngine: Create2Utils._create2Deploy('v1', type(EModeEngine).creationCode),
        borrowEngine: Create2Utils._create2Deploy('v1', type(BorrowEngine).creationCode),
        collateralEngine: Create2Utils._create2Deploy('v1', type(CollateralEngine).creationCode),
        priceFeedEngine: Create2Utils._create2Deploy('v1', type(PriceFeedEngine).creationCode),
        rateEngine: Create2Utils._create2Deploy('v1', type(RateEngine).creationCode),
        capsEngine: Create2Utils._create2Deploy('v1', type(CapsEngine).creationCode)
      });

    IAaveV3ConfigEngine.EngineConstants memory engineConstants = IAaveV3ConfigEngine
      .EngineConstants({
        pool: IPool(report.poolProxy),
        poolConfigurator: IPoolConfigurator(report.poolConfiguratorProxy),
        defaultInterestRateStrategy: report.defaultInterestRateStrategyV2,
        oracle: IAaveOracle(report.aaveOracle),
        rewardsController: report.rewardsControllerProxy,
        collector: report.treasury
      });

    return
      address(
        new AaveV3ConfigEngine(
          report.aToken,
          report.variableDebtToken,
          report.stableDebtToken,
          engineConstants,
          engineLibraries
        )
      );
  }
}
