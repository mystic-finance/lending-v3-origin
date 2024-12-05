// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '../../dependencies/openzeppelin/contracts/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {MysticVault} from './Vault.sol';

contract MysticVaultController is AccessControl {
  using SafeERC20 for IERC20;

  // Roles
  bytes32 public constant CURATOR_ROLE = keccak256('CURATOR_ROLE');

  // Mapping of supported tokens to their corresponding vaults
  mapping(address => address[]) public tokenVaults;

  // Mapping to track all created vaults
  address[] public allVaults;

  // Vault details structure
  struct VaultDetails {
    address vaultAddress;
    address baseAsset;
    bool isActive;
  }

  mapping(address => VaultDetails) public vaultRegistry;

  // Vault ranking structure for multi-vault deposit
  struct VaultRanking {
    address vaultAddress;
    uint256 totalDeposited;
    uint256 supplyAPR;
  }

  // Events
  event VaultAdded(address indexed vault, address baseAsset, address curator);
  event TokenDeposited(address indexed token, address indexed vault, uint256 amount);
  event MultiVaultDeposit(address indexed token, address[] vaults, uint256[] amounts);
  event VaultActivationChanged(address indexed vault, bool isActive);

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(CURATOR_ROLE, msg.sender);
  }

  /**
   * @dev Add an existing vault to the controller
   * @param vault Address of the vault to add
   */
  function addVault(address vault) external onlyRole(CURATOR_ROLE) {
    MysticVault mysticVault = MysticVault(vault);
    address baseAsset = mysticVault.asset();

    // Register the vault
    vaultRegistry[vault] = VaultDetails({
      vaultAddress: vault,
      baseAsset: baseAsset,
      isActive: true
    });

    // Add vault to token-vault mapping
    tokenVaults[baseAsset].push(vault);
    allVaults.push(vault);

    emit VaultAdded(vault, baseAsset, msg.sender);
  }

  /**
   * @dev Deposit tokens to a manually chosen vault
   * @param token Token to deposit
   * @param amount Amount of tokens to deposit
   * @param vault Specific vault to deposit into
   */
  function depositToSpecificVault(address token, uint256 amount, address vault) external {
    require(amount > 0, 'Amount must be greater than 0');
    require(vaultRegistry[vault].isActive, 'Vault is not active');

    // Validate vault supports the token
    MysticVault mysticVault = MysticVault(vault);
    require(mysticVault.asset() == token, 'Vault does not support this token');

    // Transfer tokens to controller
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // Deposit to specific vault
    _depositToVault(token, amount, vault);
  }

  /**
   * @dev Deposit tokens into the most suitable vault(s)
   * @param token Token to deposit
   * @param amount Amount of tokens to deposit
   */
  function depositTokens(address token, uint256 amount) external {
    require(amount > 0, 'Amount must be greater than 0');

    // Transfer tokens to controller
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // Find suitable vaults for the token
    address[] memory suitableVaults = getSuitableVaultsForToken(token);
    require(suitableVaults.length > 0, 'No suitable vaults found');

    // Split deposit if multiple vaults support the token
    if (suitableVaults.length > 1) {
      _splitDepositToTopVaults(token, amount, suitableVaults);
    } else {
      // Deposit entire amount to the single suitable vault
      _depositToVault(token, amount, suitableVaults[0]);
    }
  }

  function rankVaults(address token) external view returns (VaultRanking[] memory rankedVaults) {
    address[] memory suitableVaults = getSuitableVaultsForToken(token);
    VaultRanking[] memory rankedVaults = _rankVaults(suitableVaults);
  }

  /**
   * @dev Internal method to split deposits across top performing vaults
   * @param token Token to deposit
   * @param totalAmount Total amount to deposit
   * @param vaults Array of suitable vaults
   */
  function _splitDepositToTopVaults(
    address token,
    uint256 totalAmount,
    address[] memory vaults
  ) internal {
    // Rank vaults based on total deposited and supply APR
    VaultRanking[] memory rankedVaults = _rankVaults(vaults);

    // Choose top 3 vaults or all if less than 3
    uint256 vaultCount = rankedVaults.length > 3 ? 3 : rankedVaults.length;
    uint256 amountPerVault = totalAmount / vaultCount;
    uint256 remainderAmount = totalAmount % vaultCount;

    uint256[] memory depositAmounts = new uint256[](vaultCount);

    for (uint256 i = 0; i < vaultCount; i++) {
      uint256 depositAmount = amountPerVault + (i == 0 ? remainderAmount : 0);
      depositAmounts[i] = depositAmount;
      _depositToVault(token, depositAmount, rankedVaults[i].vaultAddress);
    }

    emit MultiVaultDeposit(token, _extractVaultAddresses(rankedVaults, vaultCount), depositAmounts);
  }

  /**
   * @dev Rank vaults based on total deposited and supply APR
   * @param vaults Array of vault addresses to rank
   * @return Ranked array of VaultRanking
   */
  function _rankVaults(address[] memory vaults) internal view returns (VaultRanking[] memory) {
    VaultRanking[] memory rankings = new VaultRanking[](vaults.length);

    for (uint256 i = 0; i < vaults.length; i++) {
      MysticVault vault = MysticVault(vaults[i]);

      // Get APR data
      MysticVault.APRData memory aprData = vault.getAPRs();

      rankings[i] = VaultRanking({
        vaultAddress: vaults[i],
        totalDeposited: vault.totalAssets(),
        supplyAPR: aprData.supplyAPR
      });
    }

    // Merge sort
    return _mergeSort(rankings);
  }

  function _mergeSort(VaultRanking[] memory arr) private pure returns (VaultRanking[] memory) {
    if (arr.length <= 1) return arr;

    uint256 mid = arr.length / 2;
    VaultRanking[] memory left = new VaultRanking[](mid);
    VaultRanking[] memory right = new VaultRanking[](arr.length - mid);

    // Split array
    for (uint256 i = 0; i < mid; i++) {
      left[i] = arr[i];
    }
    for (uint256 i = mid; i < arr.length; i++) {
      right[i - mid] = arr[i];
    }

    // Recursively sort both halves
    left = _mergeSort(left);
    right = _mergeSort(right);

    // Merge sorted halves
    return _merge(left, right);
  }

  function _merge(
    VaultRanking[] memory left,
    VaultRanking[] memory right
  ) private pure returns (VaultRanking[] memory) {
    VaultRanking[] memory result = new VaultRanking[](left.length + right.length);
    uint256 i = 0;
    uint256 j = 0;
    uint256 k = 0;

    while (i < left.length && j < right.length) {
      // Compare vaults using the same logic as quick sort
      if (_compareVaults(left[i], right[j]) >= 0) {
        result[k++] = left[i++];
      } else {
        result[k++] = right[j++];
      }
    }

    // Copy remaining elements
    while (i < left.length) {
      result[k++] = left[i++];
    }
    while (j < right.length) {
      result[k++] = right[j++];
    }

    return result;
  }

  function _compareVaults(
    VaultRanking memory a,
    VaultRanking memory b
  ) private pure returns (int256) {
    // Primary sort by supply APR (descending)
    if (a.supplyAPR != b.supplyAPR) {
      return int256(a.supplyAPR) - int256(b.supplyAPR);
    }

    // Secondary sort by total deposited (descending)
    return int256(a.totalDeposited) - int256(b.totalDeposited);
  }

  /**
   * @dev Extract vault addresses from ranked vaults
   * @param rankedVaults Ranked vault array
   * @param count Number of vaults to extract
   * @return Array of vault addresses
   */
  function _extractVaultAddresses(
    VaultRanking[] memory rankedVaults,
    uint256 count
  ) internal pure returns (address[] memory) {
    address[] memory vaultAddresses = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      vaultAddresses[i] = rankedVaults[i].vaultAddress;
    }
    return vaultAddresses;
  }

  /**
   * @dev Internal method to deposit to a specific vault
   * @param token Token to deposit
   * @param amount Amount to deposit
   * @param vault Vault address
   */
  function _depositToVault(address token, uint256 amount, address vault) internal {
    // Approve vault to spend tokens
    IERC20(token).approve(vault, amount);

    // Deposit to vault
    MysticVault(vault).deposit(amount, msg.sender);

    emit TokenDeposited(token, vault, amount);
  }

  /**
   * @dev Get vaults suitable for a specific token
   * @param token Token to find vaults for
   * @return Array of vault addresses supporting the token
   */
  function getSuitableVaultsForToken(address token) public view returns (address[] memory) {
    address[] memory candidateVaults = tokenVaults[token];

    // Filter active and suitable vaults
    address[] memory suitableVaults = new address[](candidateVaults.length);
    uint256 count = 0;

    for (uint256 i = 0; i < candidateVaults.length; i++) {
      MysticVault vault = MysticVault(candidateVaults[i]);
      if (vaultRegistry[candidateVaults[i]].isActive && vault.asset() == token) {
        suitableVaults[count] = candidateVaults[i];
        count++;
      }
    }

    // Trim the array to the actual number of suitable vaults
    assembly {
      mstore(suitableVaults, count)
    }

    return suitableVaults;
  }

  /**
   * @dev Activate or deactivate a vault
   * @param vault Vault address
   * @param isActive Activation status
   */
  function setVaultActivation(address vault, bool isActive) external onlyRole(CURATOR_ROLE) {
    require(vaultRegistry[vault].vaultAddress != address(0), 'Vault not found');
    vaultRegistry[vault].isActive = isActive;
    emit VaultActivationChanged(vault, isActive);
  }

  /**
   * @dev Get all vaults
   * @return Array of all vault addresses
   */
  function getAllVaults() external view returns (address[] memory) {
    return allVaults;
  }

  /**
   * @dev Get vaults for a specific token
   * @param token Token address
   * @return Array of vault addresses for the token
   */
  function getVaultsForToken(address token) external view returns (address[] memory) {
    return tokenVaults[token];
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
