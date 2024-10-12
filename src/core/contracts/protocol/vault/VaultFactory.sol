// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import '../../interfaces/IAaveVault.sol';
import {IVaultFactory} from '../../interfaces/IVaultFactory.sol';

import {EventsLib} from '../libraries/vault/EventsLib.sol';
import {ErrorsLib} from '../libraries/vault/ErrorsLib.sol';

import {AaveVault} from './AaveVault.sol';

/// @notice This contract allows to create MetaMorpho vaults, and to index them easily.
contract AavePoolVaultFactory is IVaultFactory {
  address public owner;
  /// @inheritdoc IVaultFactory
  mapping(address => bool) public isVault;

  /* CONSTRUCTOR */

  /// @dev Initializes the contract.
  constructor() {
    owner = msg.sender;
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
  ) external returns (IAaveVault vault) {
    vault = IAaveVault(
      address(
        new AaveVault{salt: salt}(
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
}
