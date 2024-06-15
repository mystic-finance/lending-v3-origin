// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from './PoolInstanceSemiPerm.sol';

contract SemiPermissionedPoolInstance is PoolInstance {
  constructor(IPoolAddressesProvider provider) PoolInstance(provider) {}
}
