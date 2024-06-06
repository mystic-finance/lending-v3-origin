// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TreasuryPool} from '../contracts/protocol/pool/TreasuryPool.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from './PoolInstance.sol';

contract TreasuryPoolInstance is TreasuryPool, PoolInstance {
  constructor(IPoolAddressesProvider provider) PoolInstance(provider) {}
}
