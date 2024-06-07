// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SemiPermissionedPool} from '../contracts/protocol/pool/SemiPermissionedPool.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from './PoolInstance.sol';

contract SemiPermissionedPoolInstance is SemiPermissionedPool, PoolInstance {
  constructor(IPoolAddressesProvider provider) PoolInstance(provider) {}
}
