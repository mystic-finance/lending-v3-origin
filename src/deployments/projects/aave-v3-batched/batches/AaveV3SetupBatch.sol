// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from 'src/core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import {AaveV3SetupProcedure} from '../../../contracts/procedures/AaveV3SetupProcedure.sol';
import '../../../contracts/MarketReportStorage.sol';

contract AaveV3SetupBatch is MarketReportStorage, AaveV3SetupProcedure, Ownable {
  InitialReport internal _initialReport;
  SetupReport internal _setupReport;
  address ownerMain;

  constructor(
    address _owner,
    Roles memory roles,
    MarketConfig memory config,
    MarketReport memory deployedContracts
  ) {
    ownerMain = _owner;

    _initialReport = _initialDeployment(
      deployedContracts.poolAddressesProviderRegistry,
      roles.marketOwner,
      config.marketId,
      config.providerId
    );
  }

  function setupAaveV3Market(
    Roles memory roles,
    MarketConfig memory config,
    address poolImplementation,
    address poolConfiguratorImplementation,
    address protocolDataProvider,
    address aaveOracle,
    address rewardsControllerImplementation,
    address kycPortal
  ) external onlyOwner returns (SetupReport memory) {
    _setupReport = _setupAaveV3Market(
      roles,
      config,
      _initialReport,
      poolImplementation,
      poolConfiguratorImplementation,
      protocolDataProvider,
      aaveOracle,
      rewardsControllerImplementation,
      kycPortal
    ); // 5-1

    return _setupReport;
  }

  function setMarketReport(MarketReport memory marketReport) external onlyOwner {
    _marketReport = marketReport;
    transferOwnership(ownerMain);
  }

  function getInitialReport() external view returns (InitialReport memory) {
    return _initialReport;
  }

  function getSetupReport() external view returns (SetupReport memory) {
    return _setupReport;
  }
}
