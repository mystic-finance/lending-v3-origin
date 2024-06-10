// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolConfiguratorInstance} from 'src/core/instances/PoolConfiguratorInstance.sol';
import {IPoolAddressesProvider} from 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';
import {AaveOracle} from 'src/core/contracts/misc/AaveOracle.sol';

contract AaveV3PoolConfigProcedure {
  function _deployPoolConfigurator(address poolAddressesProvider) internal returns (address) {
    PoolConfiguratorInstance poolConfiguratorImplementation = new PoolConfiguratorInstance();
    poolConfiguratorImplementation.initialize(IPoolAddressesProvider(poolAddressesProvider));

    return address(poolConfiguratorImplementation);
  }
}
