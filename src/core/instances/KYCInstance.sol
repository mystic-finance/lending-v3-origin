// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TimelockController} from '../contracts/protocol/partner/Timelock.sol';
import {IPoolAddressesProvider} from '../contracts/interfaces/IPoolAddressesProvider.sol';
import {KYCPortal} from '../contracts/protocol/partner/KYCPortal.sol';
import {Errors} from '../contracts/protocol/libraries/helpers/Errors.sol';

contract KYCInstance is KYCPortal {
  uint256 public constant PORTAL_REVISION = 2;

  constructor(address _timelock) KYCPortal(_timelock) {}

  // /**
  //  * @notice Initializes the Pool.
  //  * @dev Function is invoked by the proxy contract when the Pool contract is added to the
  //  * PoolAddressesProvider of the market.
  //  * @dev Caching the address of the PoolAddressesProvider in order to reduce gas consumption on subsequent operations
  //  * @param provider The address of the PoolAddressesProvider
  //  */
  // function initialize(IPoolAddressesProvider provider) external virtual override initializer {
  //   require(provider == ADDRESSES_PROVIDER, Errors.INVALID_ADDRESSES_PROVIDER);
  //   _maxStableRateBorrowSizePercent = 0.25e4;
  // }

  // function getRevision() internal pure virtual override returns (uint256) {
  //   return PORTAL_REVISION;
  // }
}
