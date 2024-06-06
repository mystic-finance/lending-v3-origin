// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AccessControl} from '../../dependencies/openzeppelin/contracts/AccessControl.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';

/**
 * @title ACLManager
 * @author Aave
 * @notice Access Control List Manager. Main registry of system roles and permissions.
 */
contract ACLManager is AccessControl, IACLManager {
  bytes32 public constant override POOL_ADMIN_ROLE = keccak256('POOL_ADMIN');
  bytes32 public constant override EMERGENCY_ADMIN_ROLE = keccak256('EMERGENCY_ADMIN');
  bytes32 public constant override RISK_ADMIN_ROLE = keccak256('RISK_ADMIN');
  bytes32 public constant override FLASH_BORROWER_ROLE = keccak256('FLASH_BORROWER');
  bytes32 public constant override BRIDGE_ROLE = keccak256('BRIDGE');
  bytes32 public constant override ASSET_LISTING_ADMIN_ROLE = keccak256('ASSET_LISTING_ADMIN');
  bytes32 public constant POOL_USER = keccak256('PERMISSIONED_POOL_USER');
  bytes32 public constant POOL_USER_TREASURY = keccak256('POOL_USER_TREASURY');
  bytes32 public constant POOL_USER_BOND = keccak256('POOL_USER_BOND');
  bytes32 public constant LIQUIDATOR_ADMIN = keccak256('LIQUIDATOR_ADMIN');
  bytes32 public constant LIQUIDATOR_TREASURY = keccak256('LIQUIDATOR_TREASURY');
  bytes32 public constant LIQUIDATOR_BOND = keccak256('LIQUIDATOR_BOND');
  bytes32 public constant LIQUIDATOR = keccak256('LIQUIDATOR_PERMISSIONED');

  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  /**
   * @dev Constructor
   * @dev The ACL admin should be initialized at the addressesProvider beforehand
   * @param provider The address of the PoolAddressesProvider
   */
  constructor(IPoolAddressesProvider provider) {
    ADDRESSES_PROVIDER = provider;
    address aclAdmin = provider.getACLAdmin();
    require(aclAdmin != address(0), Errors.ACL_ADMIN_CANNOT_BE_ZERO);
    _setupRole(DEFAULT_ADMIN_ROLE, aclAdmin);
  }

  /// @inheritdoc IACLManager
  function setRoleAdmin(
    bytes32 role,
    bytes32 adminRole
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    _setRoleAdmin(role, adminRole);
  }

  /// @inheritdoc IACLManager
  function addPoolAdmin(address admin) external override {
    grantRole(POOL_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function removePoolAdmin(address admin) external override {
    revokeRole(POOL_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function isPoolAdmin(address admin) external view override returns (bool) {
    return hasRole(POOL_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function addEmergencyAdmin(address admin) external override {
    grantRole(EMERGENCY_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function removeEmergencyAdmin(address admin) external override {
    revokeRole(EMERGENCY_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function isEmergencyAdmin(address admin) external view override returns (bool) {
    return hasRole(EMERGENCY_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function addRiskAdmin(address admin) external override {
    grantRole(RISK_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function removeRiskAdmin(address admin) external override {
    revokeRole(RISK_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function isRiskAdmin(address admin) external view override returns (bool) {
    return hasRole(RISK_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function addFlashBorrower(address borrower) external override {
    grantRole(FLASH_BORROWER_ROLE, borrower);
  }

  /// @inheritdoc IACLManager
  function removeFlashBorrower(address borrower) external override {
    revokeRole(FLASH_BORROWER_ROLE, borrower);
  }

  /// @inheritdoc IACLManager
  function isFlashBorrower(address borrower) external view override returns (bool) {
    return hasRole(FLASH_BORROWER_ROLE, borrower);
  }

  /// @inheritdoc IACLManager
  function addBridge(address bridge) external override {
    grantRole(BRIDGE_ROLE, bridge);
  }

  /// @inheritdoc IACLManager
  function removeBridge(address bridge) external override {
    revokeRole(BRIDGE_ROLE, bridge);
  }

  /// @inheritdoc IACLManager
  function isBridge(address bridge) external view override returns (bool) {
    return hasRole(BRIDGE_ROLE, bridge);
  }

  /// @inheritdoc IACLManager
  function addAssetListingAdmin(address admin) external override {
    grantRole(ASSET_LISTING_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function removeAssetListingAdmin(address admin) external override {
    revokeRole(ASSET_LISTING_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function isAssetListingAdmin(address admin) external view override returns (bool) {
    return hasRole(ASSET_LISTING_ADMIN_ROLE, admin);
  }

  /// @inheritdoc IACLManager
  function addPoolUser(address admin) external override {
    grantRole(POOL_USER, admin);
  }

  /// @inheritdoc IACLManager
  function removePoolUser(address admin) external override {
    revokeRole(POOL_USER, admin);
  }

  /// @inheritdoc IACLManager
  function isPoolUser(address admin) external view override returns (bool) {
    return hasRole(POOL_USER, admin);
  }

  /// @inheritdoc IACLManager
  function addTreasuryPoolUser(address admin) external override {
    grantRole(POOL_USER_TREASURY, admin);
  }

  /// @inheritdoc IACLManager
  function removeTreasuryPoolUser(address admin) external override {
    revokeRole(POOL_USER_TREASURY, admin);
  }

  /// @inheritdoc IACLManager
  function isTreasuryPoolUser(address admin) external view override returns (bool) {
    return hasRole(POOL_USER_TREASURY, admin);
  }

  /// @inheritdoc IACLManager
  function addBondPoolUser(address admin) external override {
    grantRole(POOL_USER_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function removeBondPoolUser(address admin) external override {
    revokeRole(POOL_USER_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function isBondPoolUser(address admin) external view override returns (bool) {
    return hasRole(POOL_USER_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function addLiquidatorAdmin(address admin) external override {
    grantRole(LIQUIDATOR_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function removeLiquidatorAdmin(address admin) external override {
    revokeRole(LIQUIDATOR_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function isLiquidatorAdmin(address admin) external view override returns (bool) {
    return hasRole(LIQUIDATOR_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function addLiquidator(address admin) external override {
    grantRole(LIQUIDATOR, admin);
  }

  /// @inheritdoc IACLManager
  function removeLiquidator(address admin) external override {
    revokeRole(LIQUIDATOR, admin);
  }

  /// @inheritdoc IACLManager
  function isLiquidator(address admin) external view override returns (bool) {
    return hasRole(LIQUIDATOR, admin);
  }

  /// @inheritdoc IACLManager
  function addBondLiquidator(address admin) external override {
    grantRole(LIQUIDATOR_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function removeBondLiquidator(address admin) external override {
    revokeRole(LIQUIDATOR_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function isBondLiquidator(address admin) external view override returns (bool) {
    return hasRole(LIQUIDATOR_BOND, admin);
  }

  /// @inheritdoc IACLManager
  function addTreasuryLiquidator(address admin) external override {
    grantRole(LIQUIDATOR_TREASURY, admin);
  }

  /// @inheritdoc IACLManager
  function removeTreasuryLiquidator(address admin) external override {
    revokeRole(LIQUIDATOR_TREASURY, admin);
  }

  /// @inheritdoc IACLManager
  function isTreasuryLiquidator(address admin) external view override returns (bool) {
    return hasRole(LIQUIDATOR_TREASURY, admin);
  }
}
