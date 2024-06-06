// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermissionedPool} from '../contracts/protocol/pool/PermissionedPool.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from './PoolInstance.sol';

contract PermissionedPoolInstance is PermissionedPool, PoolInstance {
  constructor(IPoolAddressesProvider provider) PoolInstance(provider) {}
}
