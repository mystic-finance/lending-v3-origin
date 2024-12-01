// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {Ownable} from '../../dependencies/openzeppelin/contracts/Ownable.sol';
import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {MysticIdentity} from './KYCId.sol';

contract KYCPortal is Ownable {
  using SafeMath for uint256;
  address timelock;
  MysticIdentity identity;
  // IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  struct Partner {
    bool isActive;
    uint256 timestampAdded;
    Liquidator[] liquidators;
  }

  struct User {
    bool isActive;
    uint8 poolType;
  }

  struct Liquidator {
    uint8 liquidatorType;
    address liquidator;
    address addressProvider;
  }

  mapping(bytes32 => Partner) internal partners;
  mapping(bytes32 => bool) internal poolUsers;
  mapping(address => bool) internal relayers;

  event PartnerAdded(address indexed partner);
  event UserAdded(address indexed partner, uint8 poolType);
  event LiquidatorAdded(address indexed partner, address indexed liquidator);
  event LiquidatorRemoved(address indexed partner, address indexed liquidator);
  event PartnerRemoved(address indexed partner);
  event UserRemoved(address indexed partner, uint8 poolType);

  constructor(address _timelock, address _identity, address _addressProvider) {
    relayers[msg.sender] = true;
    identity = MysticIdentity(_identity);
    // renounce ownership to timelock contract to avoid multiple ownership
    relayers[_timelock] = true;
    timelock = _timelock;

    transferOwnership(_timelock);
    IACLManager(IPoolAddressesProvider(_addressProvider).getACLManager()).addLiquidatorAdmin(
      _timelock
    );
  }

  modifier onlyRelayer() {
    require(
      relayers[msg.sender] || owner() == msg.sender,
      'Only the relayer or owner can call this function'
    );
    _;
  }

  /**
   * @dev Only approved liquidator can call functions marked by this modifier.
   */
  modifier onlyLiquidatorAdmin(IPoolAddressesProvider _addressProvider) {
    _onlyLiquidatorAdmin(_addressProvider);
    _;
  }

  function _onlyLiquidatorAdmin(IPoolAddressesProvider _addressProvider) internal view virtual {
    require(
      IACLManager(_addressProvider.getACLManager()).isLiquidatorAdmin(msg.sender),
      Errors.CALLER_NOT_POOL_ADMIN
    );
  }

  function _addAllPermissions(address partner, IPoolAddressesProvider _addressProvider) internal {
    _verifyIdentity(partner);

    IACLManager(_addressProvider.getACLManager()).addPoolUser(partner);

    IACLManager(_addressProvider.getACLManager()).addRegulatedPoolUser(partner);

    IACLManager(_addressProvider.getACLManager()).addInvestorPoolUser(partner);
  }

  function _verifyIdentity(address user) internal {
    require(
      identity.balanceOf(user) == 1,
      'Unique Identity Per User is needed before permission can be given'
    );
  }

  function _addPermissions(
    address partner,
    uint8 poolType,
    IPoolAddressesProvider _addressProvider
  ) internal {
    _verifyIdentity(partner);

    if (poolType == 0) {
      IACLManager(_addressProvider.getACLManager()).addPoolUser(partner);
    } else if (poolType == 1) {
      IACLManager(_addressProvider.getACLManager()).addRegulatedPoolUser(partner);
    } else if (poolType == 2) {
      IACLManager(_addressProvider.getACLManager()).addInvestorPoolUser(partner);
    }
  }

  function _removeAllPermissions(
    address partner,
    IPoolAddressesProvider _addressProvider
  ) internal {
    IACLManager(_addressProvider.getACLManager()).removePoolUser(partner);

    IACLManager(_addressProvider.getACLManager()).removeRegulatedPoolUser(partner);

    IACLManager(_addressProvider.getACLManager()).removeInvestorPoolUser(partner);
  }

  function _removePermissions(
    address partner,
    uint8 poolType,
    IPoolAddressesProvider _addressProvider
  ) internal {
    if (poolType == 0) {
      IACLManager(_addressProvider.getACLManager()).removePoolUser(partner);
    } else if (poolType == 1) {
      IACLManager(_addressProvider.getACLManager()).removeRegulatedPoolUser(partner);
    } else if (poolType == 2) {
      IACLManager(_addressProvider.getACLManager()).removeInvestorPoolUser(partner);
    }
  }

  function _addLiquidationPermissions(
    address liquidator,
    uint8 liquidationType,
    IPoolAddressesProvider _addressProvider
  ) internal {
    _verifyIdentity(liquidator);

    if (liquidationType == 0) {
      IACLManager(_addressProvider.getACLManager()).addLiquidator(liquidator);
    } else if (liquidationType == 1) {
      IACLManager(_addressProvider.getACLManager()).addInvestorLiquidator(liquidator);
    } else if (liquidationType == 2) {
      IACLManager(_addressProvider.getACLManager()).addRegulatedLiquidator(liquidator);
    }
  }

  function _removeLiquidationPermissions(
    address liquidator,
    uint8 liquidationType,
    IPoolAddressesProvider _addressProvider
  ) internal {
    if (liquidationType == 0) {
      IACLManager(_addressProvider.getACLManager()).removeLiquidator(liquidator);
    } else if (liquidationType == 1) {
      IACLManager(_addressProvider.getACLManager()).removeInvestorLiquidator(liquidator);
    } else if (liquidationType == 2) {
      IACLManager(_addressProvider.getACLManager()).removeRegulatedLiquidator(liquidator);
    }
  }

  function _findLiquidatorFromArray(
    Liquidator[] memory arr,
    Liquidator calldata liquidator,
    address _addressProvider
  ) internal pure returns (uint) {
    uint index = 0;

    for (uint i = 0; i < arr.length - 1; i++) {
      if (
        arr[i].liquidator == liquidator.liquidator &&
        arr[i].liquidatorType == liquidator.liquidatorType &&
        arr[i].addressProvider == _addressProvider
      ) {
        index = i;
        return i + 1;
      }
    }

    return 0;
  }

  /**
   * @dev add approved relayer.
   */
  function addRelayer(address relayer) public onlyOwner {
    relayers[relayer] = true;
  }

  /**
   * @dev add approved pool users.
   */
  function addPoolUsers(
    address user,
    uint8 poolType,
    IPoolAddressesProvider _addressProvider
  ) public onlyRelayer {
    bytes32 _hash = keccak256(abi.encode(user, poolType, _addressProvider));

    require(!poolUsers[_hash], 'User already added');
    require(poolType < 3, 'pool type is limited');
    poolUsers[_hash] = true;

    _addPermissions(user, poolType, _addressProvider);

    emit UserAdded(user, poolType);
  }

  /**
   * @dev remove approved pool users.
   */
  function removePoolUsers(
    address user,
    uint8 poolType,
    IPoolAddressesProvider _addressProvider
  ) public onlyRelayer {
    bytes32 _hash = keccak256(abi.encode(user, poolType, _addressProvider));

    require(poolUsers[_hash], 'User not added');
    require(poolType < 3, 'pool type is limited');
    poolUsers[_hash] = false;

    _removePermissions(user, poolType, _addressProvider);

    emit UserRemoved(user, poolType);
  }

  /**
   * @dev add approved pool partner.
   */
  function addPartner(
    address partner,
    IPoolAddressesProvider _addressProvider
  ) external onlyRelayer {
    bytes32 _hash = keccak256(abi.encode(partner, _addressProvider));
    require(!partners[_hash].isActive, 'Partner already added');

    // Initialize the partner struct in storage
    Partner storage partnerData = partners[_hash];
    partnerData.isActive = true;
    partnerData.timestampAdded = block.timestamp;

    uint8[3] memory types = [0, 1, 2];
    for (uint8 i = 0; i < types.length; ) {
      bytes32 _subhash = keccak256(abi.encode(partner, types[i], _addressProvider));
      if (!poolUsers[_subhash]) {
        // allow partner to have the basic role of pool users too
        poolUsers[_subhash] = true;
      }

      unchecked {
        ++i;
      }
    }

    _addAllPermissions(partner, _addressProvider);

    // // Initialize the liquidators array in storage
    // partnerData.liquidators.push();

    IACLManager(_addressProvider.getACLManager()).addLiquidatorAdmin(partner);

    emit PartnerAdded(partner);
  }

  /**
   * @dev remove approved pool partner.
   */
  function removePartner(
    address partner,
    IPoolAddressesProvider _addressProvider
  ) external onlyRelayer {
    bytes32 _hash = keccak256(abi.encode(partner, _addressProvider));
    require(partners[_hash].isActive, 'Partner not added');

    Liquidator[] memory liquidators = partners[_hash].liquidators;
    partners[_hash].isActive = true;
    partners[_hash].timestampAdded = block.timestamp;

    for (uint i = 0; i < liquidators.length; ) {
      _removeLiquidationPermissions(
        liquidators[i].liquidator,
        liquidators[i].liquidatorType,
        _addressProvider
      );

      unchecked {
        i++;
      }
    }

    uint8[3] memory types = [0, 1, 2];
    for (uint8 i = 0; i < types.length; ) {
      bytes32 _subhash = keccak256(abi.encode(partner, types[i], _addressProvider));
      if (poolUsers[_subhash]) {
        // remove partner from the basic role of pool users too
        poolUsers[_subhash] = false;
      }

      unchecked {
        ++i;
      }
    }

    _removeAllPermissions(partner, _addressProvider);

    IACLManager(_addressProvider.getACLManager()).removeLiquidatorAdmin(partner);

    emit PartnerRemoved(partner);
  }

  function addLiquidator(
    Liquidator calldata liquidator,
    IPoolAddressesProvider _addressProvider
  ) external {
    _onlyLiquidatorAdmin(_addressProvider);

    bytes32 _hash = keccak256(abi.encode(msg.sender, _addressProvider));
    require(partners[_hash].isActive, 'Partner not found');
    partners[_hash].liquidators.push(
      Liquidator(liquidator.liquidatorType, liquidator.liquidator, address(_addressProvider))
    );

    _addLiquidationPermissions(liquidator.liquidator, liquidator.liquidatorType, _addressProvider);
    emit LiquidatorAdded(msg.sender, liquidator.liquidator);
  }

  function removeLiquidator(
    Liquidator calldata liquidator,
    IPoolAddressesProvider _addressProvider
  ) external {
    _onlyLiquidatorAdmin(_addressProvider);

    bytes32 _hash = keccak256(abi.encode(msg.sender, _addressProvider));
    require(partners[_hash].isActive, 'Partner not found');

    uint index = _findLiquidatorFromArray(
      partners[_hash].liquidators,
      liquidator,
      address(_addressProvider)
    );

    if (index > 0) {
      partners[_hash].liquidators[index] = partners[_hash].liquidators[
        partners[_hash].liquidators.length - 1
      ];
      // Remove the last element
      partners[_hash].liquidators.pop();
    }

    _removeLiquidationPermissions(
      liquidator.liquidator,
      liquidator.liquidatorType,
      _addressProvider
    );

    emit LiquidatorRemoved(msg.sender, liquidator.liquidator);
  }
}
