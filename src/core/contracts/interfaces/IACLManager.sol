// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';

/**
 * @title IACLManager
 * @author Aave
 * @notice Defines the basic interface for the ACL Manager
 */
interface IACLManager {
  /**
   * @notice Returns the contract address of the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the identifier of the PoolAdmin role
   * @return The id of the PoolAdmin role
   */
  function POOL_ADMIN_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the identifier of the EmergencyAdmin role
   * @return The id of the EmergencyAdmin role
   */
  function EMERGENCY_ADMIN_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the identifier of the RiskAdmin role
   * @return The id of the RiskAdmin role
   */
  function RISK_ADMIN_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the identifier of the FlashBorrower role
   * @return The id of the FlashBorrower role
   */
  function FLASH_BORROWER_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the identifier of the Bridge role
   * @return The id of the Bridge role
   */
  function BRIDGE_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the identifier of the AssetListingAdmin role
   * @return The id of the AssetListingAdmin role
   */
  function ASSET_LISTING_ADMIN_ROLE() external view returns (bytes32);

  /**
   * @notice Set the role as admin of a specific role.
   * @dev By default the admin role for all roles is `DEFAULT_ADMIN_ROLE`.
   * @param role The role to be managed by the admin role
   * @param adminRole The admin role
   */
  function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

  /**
   * @notice Adds a new admin as PoolAdmin
   * @param admin The address of the new admin
   */
  function addPoolAdmin(address admin) external;

  /**
   * @notice Removes an admin as PoolAdmin
   * @param admin The address of the admin to remove
   */
  function removePoolAdmin(address admin) external;

  /**
   * @notice Returns true if the address is PoolAdmin, false otherwise
   * @param admin The address to check
   * @return True if the given address is PoolAdmin, false otherwise
   */
  function isPoolAdmin(address admin) external view returns (bool);

  /**
   * @notice Adds a new admin as EmergencyAdmin
   * @param admin The address of the new admin
   */
  function addEmergencyAdmin(address admin) external;

  /**
   * @notice Removes an admin as EmergencyAdmin
   * @param admin The address of the admin to remove
   */
  function removeEmergencyAdmin(address admin) external;

  /**
   * @notice Returns true if the address is EmergencyAdmin, false otherwise
   * @param admin The address to check
   * @return True if the given address is EmergencyAdmin, false otherwise
   */
  function isEmergencyAdmin(address admin) external view returns (bool);

  /**
   * @notice Adds a new admin as RiskAdmin
   * @param admin The address of the new admin
   */
  function addRiskAdmin(address admin) external;

  /**
   * @notice Removes an admin as RiskAdmin
   * @param admin The address of the admin to remove
   */
  function removeRiskAdmin(address admin) external;

  /**
   * @notice Returns true if the address is RiskAdmin, false otherwise
   * @param admin The address to check
   * @return True if the given address is RiskAdmin, false otherwise
   */
  function isRiskAdmin(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as FlashBorrower
   * @param borrower The address of the new FlashBorrower
   */
  function addFlashBorrower(address borrower) external;

  /**
   * @notice Removes an address as FlashBorrower
   * @param borrower The address of the FlashBorrower to remove
   */
  function removeFlashBorrower(address borrower) external;

  /**
   * @notice Returns true if the address is FlashBorrower, false otherwise
   * @param borrower The address to check
   * @return True if the given address is FlashBorrower, false otherwise
   */
  function isFlashBorrower(address borrower) external view returns (bool);

  /**
   * @notice Adds a new address as Bridge
   * @param bridge The address of the new Bridge
   */
  function addBridge(address bridge) external;

  /**
   * @notice Removes an address as Bridge
   * @param bridge The address of the bridge to remove
   */
  function removeBridge(address bridge) external;

  /**
   * @notice Returns true if the address is Bridge, false otherwise
   * @param bridge The address to check
   * @return True if the given address is Bridge, false otherwise
   */
  function isBridge(address bridge) external view returns (bool);

  /**
   * @notice Adds a new admin as AssetListingAdmin
   * @param admin The address of the new admin
   */
  function addAssetListingAdmin(address admin) external;

  /**
   * @notice Removes an admin as AssetListingAdmin
   * @param admin The address of the admin to remove
   */
  function removeAssetListingAdmin(address admin) external;

  /**
   * @notice Returns true if the address is AssetListingAdmin, false otherwise
   * @param admin The address to check
   * @return True if the given address is AssetListingAdmin, false otherwise
   */
  function isAssetListingAdmin(address admin) external view returns (bool);

   /**
   * @notice Adds a new address as Pool User for permisionless pools
   * @param admin The address of the new pool user
   */
  function addPoolUser(address admin) external;

  /**
   * @notice Removes an address as Pool User
   * @param admin The address of the pool user to remove
   */
  function removePoolUser(address admin) external;

  /**
   * @notice Returns true if the address is Pool User, false otherwise
   * @param admin The address to check
   * @return True if the given address is Pool User, false otherwise
   */
  function isPoolUser(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as Pool User for treasury pools
   * @param admin The address of the new pool user
   */
  function addTreasuryPoolUser(address admin) external;

  /**
   * @notice Removes an address as Pool User For Treasury Pool
   * @param admin The address of the pool user to remove
   */
  function removeTreasuryPoolUser(address admin) external;

  /**
   * @notice Returns true if the address is Treasury Pool User, false otherwise
   * @param admin The address to check
   * @return True if the given address is Pool User, false otherwise
   */
  function isTreasuryPoolUser(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as Pool User for bond pools
   * @param admin The address of the new pool user
   */
  function addBondPoolUser(address admin) external;

  /**
   * @notice Removes an address as Pool User For Bond Pool
   * @param admin The address of the pool user to remove
   */
  function removeBondPoolUser(address admin) external;

  /**
   * @notice Returns true if the address is Bond Pool User, false otherwise
   * @param admin The address to check
   * @return True if the given address is Pool User, false otherwise
   */
  function isBondPoolUser(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as a liquidator admin usually a partner
   * @param admin The address of the new liquidator admin
   */
  function addLiquidatorAdmin(address admin) external;

   /**
   * @notice Removes an address as a liquidator admin usually a partner
   * @param admin The address of the liquidator admin to remove
   */
  function removeLiquidatorAdmin(address admin) external;

  /**
   * @notice Returns true if the address is Liquidator admin, false otherwise
   * @param admin The address to check
   * @return True if the given address is LIquidator admin, false otherwise
   */
  function isLiquidatorAdmin(address admin) external view returns (bool) ;

  /**
   * @notice Adds a new address as a permissioned liquidator usually a partner
   * @param admin The address of the new permissioned liquidator
   */
  function addLiquidator(address admin) external;

  /**
   * @notice Removes an address as a permissioned liquidator usually a partner
   * @param admin The address of the permissioned liquidator to remove
   */
  function removeLiquidator(address admin) external;

  /**
   * @notice Returns true if the address is Permissioned Liquidator, false otherwise
   * @param admin The address to check
   * @return True if the given address is Permissioned Liquidator, false otherwise
   */
  function isLiquidator(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as a permissioned bond liquidator usually a partner
   * @param admin The address of the new permissioned liquidator
   */
  function addBondLiquidator(address admin) external;

   /**
   * @notice Removes an address as a permissioned bond liquidator usually a partner
   * @param admin The address of the permissioned liquidator to remove
   */
  function removeBondLiquidator(address admin) external;

  /**
   * @notice Returns true if the address is Permissioned Bond Liquidator, false otherwise
   * @param admin The address to check
   * @return True if the given address is Permissioned Bond Liquidator, false otherwise
   */
  function isBondLiquidator(address admin) external view returns (bool);

  /**
   * @notice Adds a new address as a permissioned treasury liquidator usually a partner
   * @param admin The address of the new permissioned liquidator
   */
  function addTreasuryLiquidator(address admin) external;

   /**
   * @notice Removes an address as a permissioned treasury liquidator usually a partner
   * @param admin The address of the permissioned treasury liquidator to remove
   */
  function removeTreasuryLiquidator(address admin) external;

  /**
   * @notice Returns true if the address is Permissioned Treasury Liquidator, false otherwise
   * @param admin The address to check
   * @return True if the given address is Permissioned Liquidator, false otherwise
   */
  function isTreasuryLiquidator(address admin) external view returns (bool) ;
}
