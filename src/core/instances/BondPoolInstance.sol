// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BondPool} from '../contracts/protocol/pool/BondPool.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from './PoolInstance.sol';

contract BondPoolInstance is BondPool, PoolInstance {
  constructor(IPoolAddressesProvider provider) PoolInstance(provider) {}
}
