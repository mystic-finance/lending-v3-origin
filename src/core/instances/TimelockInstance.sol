// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TimelockController} from '../contracts/protocol/partner/Timelock.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {KYCPortal} from '../contracts/protocol/partner/KYCPortal.sol';
import {Errors} from '../contracts/protocol/libraries/helpers/Errors.sol';

contract TimelockInstance is TimelockController {
  constructor(
    address _admin,
    uint _delay,
    address[] memory _executors
  ) TimelockController(_delay, _executors, _executors, _admin) {}
}
