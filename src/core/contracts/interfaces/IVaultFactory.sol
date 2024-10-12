// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IAaveVault} from './IAaveVault.sol';

/// @title IVaultFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Vault's factory.
interface IVaultFactory {
  // /// @notice The address of the Morpho contract.
  // function MORPHO() external view returns (address);

  /// @notice Whether a vault was created with the factory.
  function isVault(address target) external view returns (bool);

  /// @notice Creates a new vault.
  /// @param initialTimelock The initial timelock of the vault.
  /// @param asset The address of the underlying asset.
  /// @param name The name of the vault.
  /// @param symbol The symbol of the vault.
  /// @param salt The salt to use for the vault's CREATE2 address.
  function createVault(
    uint256 initialTimelock,
    address asset,
    uint256 maxDeposit,
    uint256 maxWithdrawal,
    uint256 fee,
    address feeRecipient,
    string memory name,
    string memory symbol,
    bytes32 salt
  ) external returns (IAaveVault vault);
}
