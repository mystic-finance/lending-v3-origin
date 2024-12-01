// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import '../../interfaces/IMysticVault.sol';
import {IVaultFactory} from '../../interfaces/IVaultFactory.sol';

import {EventsLib} from '../libraries/vault/EventsLib.sol';
import {ErrorsLib} from '../libraries/vault/ErrorsLib.sol';

import {MysticVault} from './Vault.sol';
import {MysticVaultController} from './VaultController.sol';
import '../../dependencies/openzeppelin/contracts/AccessControl.sol';

/// @notice This contract allows to create MetaMorpho vaults, and to index them easily.
contract MysticPoolVaultFactory is IVaultFactory, AccessControl {
  address public owner;
  address public vaultController;
  /// @inheritdoc IVaultFactory
  mapping(address => bool) public isVault;
  // Roles
  bytes32 public constant CURATOR_ROLE = keccak256('CURATOR_ROLE');

  /* CONSTRUCTOR */

  /// @dev Initializes the contract.
  constructor(address _vaultController) {
    vaultController = _vaultController;
    owner = msg.sender;
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(CURATOR_ROLE, msg.sender);
  }

  /* EXTERNAL */

  /// @inheritdoc IVaultFactory
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
  ) external onlyRole(CURATOR_ROLE) returns (IMysticVault vault) {
    vault = IMysticVault(
      address(
        new MysticVault{salt: salt}(
          asset,
          initialTimelock,
          owner,
          msg.sender,
          maxDeposit,
          maxWithdrawal,
          fee,
          feeRecipient,
          name,
          symbol
        )
      )
    );

    isVault[address(vault)] = true;
    MysticVaultController(vaultController).addVault(address(vault));

    emit EventsLib.CreateVault(
      address(vault),
      msg.sender,
      owner,
      initialTimelock,
      asset,
      name,
      symbol,
      salt
    );
  }

  /**
   * @dev Add a curator role
   * @param curator Address to grant curator role
   */
  function addCurator(address curator) external onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(CURATOR_ROLE, curator);
  }

  /**
   * @dev Remove a curator role
   * @param curator Address to revoke curator role
   */
  function removeCurator(address curator) external onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(CURATOR_ROLE, curator);
  }
}
