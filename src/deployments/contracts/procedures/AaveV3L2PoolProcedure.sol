// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {L2PoolInstance} from 'src/core/instances/L2PoolInstance.sol';
import {PermissionedPoolInstance} from 'src/core/instances/PermissionedPoolInstance.sol';

import {SemiPermissionedPoolInstance} from 'src/core/instances/SemiPermissionedPoolInstance.sol';

import {KYCInstance} from 'src/core/instances/KYCInstance.sol';

import {IPoolAddressesProvider} from 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
import {AaveV3PoolConfigProcedure} from './AaveV3PoolConfigProcedure.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';
import {IErrors} from '../../interfaces/IErrors.sol';
import '../../interfaces/IMarketReportTypes.sol';

contract AaveV3L2PoolProcedure is AaveV3PoolConfigProcedure, IErrors {
  function _deployAaveV3L2Pool(address poolAddressesProvider) internal returns (PoolReport memory) {
    if (poolAddressesProvider == address(0)) revert ProviderNotFound();

    PoolReport memory report;

    report.poolImplementation = _deployL2PoolImpl(poolAddressesProvider);
    // report.bondPoolImplementation = _deployBondPoolImpl(poolAddressesProvider);
    // report.permissionedPoolImplementation = _deployL2PoolImpl(poolAddressesProvider);
    // report.treasuryPoolImplementation = _deployTreasuryPoolImpl(poolAddressesProvider);
    report.poolConfiguratorImplementation = _deployPoolConfigurator(poolAddressesProvider);

    return report;
  } //3-1-1

  function _deployAaveV3PermPool(
    address poolAddressesProvider
  ) internal returns (PoolReport memory) {
    if (poolAddressesProvider == address(0)) revert ProviderNotFound();

    PoolReport memory report;

    report.poolImplementation = _deployPermissionedPoolImpl(poolAddressesProvider);
    // report.bondPoolImplementation = _deployBondPoolImpl(poolAddressesProvider);
    // report.permissionedPoolImplementation = _deployL2PoolImpl(poolAddressesProvider);
    // report.treasuryPoolImplementation = _deployTreasuryPoolImpl(poolAddressesProvider);
    report.poolConfiguratorImplementation = _deployPoolConfigurator(poolAddressesProvider);

    return report;
  } //3-1-1

  function _deployAaveV3SemiPermPool(
    address poolAddressesProvider
  ) internal returns (PoolReport memory) {
    if (poolAddressesProvider == address(0)) revert ProviderNotFound();

    PoolReport memory report;

    report.poolImplementation = _deploySemiPermissionedPoolImpl(poolAddressesProvider);
    // report.bondPoolImplementation = _deployBondPoolImpl(poolAddressesProvider);
    // report.permissionedPoolImplementation = _deployL2PoolImpl(poolAddressesProvider);
    // report.treasuryPoolImplementation = _deployTreasuryPoolImpl(poolAddressesProvider);
    report.poolConfiguratorImplementation = _deployPoolConfigurator(poolAddressesProvider);

    return report;
  } //3-1-1

  // function _deployAaveKycPortal(
  //   address poolAddressesProvider,
  //   address deployer
  // ) internal returns (PartnerReport memory) {
  //   if (poolAddressesProvider == address(0)) revert ProviderNotFound();

  //   PartnerReport memory report;

  //   report.timelock = _deployTimelock(deployer);
  //   report.kycPortal = _deployKycPortal(poolAddressesProvider, report.timelock);

  //   return report;
  // }

  // function _deployTimelock(address admin) internal returns (address) {
  //   address[] memory executors = new address[](2);
  //   executors[0] = admin;
  //   executors[1] = msg.sender;
  //   address timelock = address(new TimelockInstance(admin, 20 minutes, executors));

  //   return timelock;
  // }

  // function _deployKycPortal(
  //   address poolAddressesProvider,
  //   address timelock
  // ) internal returns (address) {
  //   address kycPortal = address(new KYCInstance(timelock));

  //   return kycPortal;
  // }

  function _deployL2PoolImpl(address poolAddressesProvider) internal returns (address) {
    address l2Pool = address(new L2PoolInstance(IPoolAddressesProvider(poolAddressesProvider)));

    L2PoolInstance(l2Pool).initialize(IPoolAddressesProvider(poolAddressesProvider));

    return l2Pool;
  }

  function _deployPermissionedPoolImpl(address poolAddressesProvider) internal returns (address) {
    address l2Pool = address(
      new PermissionedPoolInstance(IPoolAddressesProvider(poolAddressesProvider))
    );

    PermissionedPoolInstance(l2Pool).initialize(IPoolAddressesProvider(poolAddressesProvider));

    return l2Pool;
  }

  function _deploySemiPermissionedPoolImpl(
    address poolAddressesProvider
  ) internal returns (address) {
    address l2Pool = address(
      new SemiPermissionedPoolInstance(IPoolAddressesProvider(poolAddressesProvider))
    );

    SemiPermissionedPoolInstance(l2Pool).initialize(IPoolAddressesProvider(poolAddressesProvider));

    return l2Pool;
  }
}
