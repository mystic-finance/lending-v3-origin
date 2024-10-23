// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from '../dependencies/openzeppelin/contracts/IERC4626.sol';

interface IMysticVault is IERC4626 {
  struct AssetAllocation {
    address asset;
    address aToken;
    address oracle;
    uint256 allocationPercentage;
  }

  struct WithdrawalRequest {
    address user;
    uint256 assets;
    uint256 requestTime;
  }

  /// @notice Adds a new curator to the vault
  /// @param curator Address of the new curator
  function addCurator(address curator) external;

  /// @notice Removes a curator from the vault
  /// @param curator Address of the curator to be removed
  function removeCurator(address curator) external;

  /// @notice Adds a new asset allocation to the vault
  /// @param asset Address of the asset
  /// @param aToken Address of the corresponding aToken
  /// @param oracle Address of the price oracle for the asset
  /// @param allocationPercentage Percentage of allocation for this asset (in basis points)
  /// @param mysticPoolAddress Address of the Mystic pool for this asset
  function addAssetAllocation(
    address asset,
    address aToken,
    address oracle,
    uint256 allocationPercentage,
    address mysticPoolAddress
  ) external;

  /// @notice Updates the allocation percentage for an existing asset
  /// @param asset Address of the asset
  /// @param mysticPoolAddress Address of the Mystic pool for this asset
  /// @param newAllocationPercentage New allocation percentage (in basis points)
  function updateAssetAllocation(
    address asset,
    address mysticPoolAddress,
    uint256 newAllocationPercentage
  ) external;

  /// @notice Reallocates assets based on the new allocation percentage
  /// @param asset Address of the asset to reallocate
  /// @param mysticPoolAddress Address of the Mystic pool for this asset
  /// @param newAllocationPercentage New allocation percentage (in basis points)
  function reallocate(
    address asset,
    address mysticPoolAddress,
    uint256 newAllocationPercentage
  ) external;

  /// @notice Requests a withdrawal for the caller
  /// @param shares Number of shares to withdraw
  function requestWithdrawal(uint256 shares) external;

  /// @notice Accrues fees for the vault
  // function accrueFees() external;

  /// @notice Allows the fee recipient to withdraw accrued fees
  function withdrawFees() external;

  /// @notice Simulates a withdrawal and returns the number of shares that would be redeemed
  /// @param assets Amount of assets to simulate withdrawal for
  /// @return Number of shares that would be redeemed
  function simulateWithdrawal(uint256 assets) external view returns (uint256);

  /// @notice Simulates a supply and returns the number of shares that would be minted
  /// @param assets Amount of assets to simulate supply for
  /// @return Number of shares that would be minted
  function simulateSupply(uint256 assets) external view returns (uint256);

  /// @notice Checks if an asset and Mystic pool combination is supported by the vault
  /// @param asset Address of the asset
  /// @param mysticPool Address of the Mystic pool
  /// @return Boolean indicating if the asset and pool combination is supported
  // function isAssetAndPoolSupported(address asset, address mysticPool) external view returns (bool);

  /// @notice Returns the current withdrawal timelock period
  /// @return The withdrawal timelock period in seconds
  function withdrawalTimelock() external view returns (uint256);

  /// @notice Returns the maximum deposit amount allowed
  /// @return The maximum deposit amount
  function maxDeposit(address) external view returns (uint256);

  /// @notice Returns the maximum withdrawal amount allowed
  /// @return The maximum withdrawal amount
  function maxWithdrawal(address) external view returns (uint256);

  /// @notice Returns the current fee percentage
  /// @return The fee percentage in basis points
  function fee() external view returns (uint256);

  /// @notice Returns the address of the fee recipient
  /// @return The address of the fee recipient
  function feeRecipient() external view returns (address);
}
