// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {DataTypes} from 'src/core/contracts/protocol/libraries/types/DataTypes.sol';
import {IVariableDebtToken} from 'src/core/contracts/interfaces/IVariableDebtToken.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

interface IVault {
  function stake(address asset, address to, uint256 amount) external;
  function redeem(address asset, address to, uint256 amount) external;
  function emergencyWithdraw(address asset, uint256 amount) external;
  function coverBadDebt(address asset, uint256 amount) external;
}

/// @title TrancheRouter
/// @notice This contract wraps user deposits by splitting funds between a junior tranche (pool) and a senior tranche (vault).
/// @dev One wrapper is deployed per vault while supporting multiple pools. It includes admin functions to add pools,
/// set the vault, configure the deposit split, and a rebalancing function to coordinate funds between the two tranches.
contract TrancheRouter is Ownable {
  using Math for uint256;
  using SafeERC20 for IERC20;

  struct TrancheConfig {
    address vault;
    uint256 outstandingDebt;
    uint256 juniorRatio; // in bps
    uint256 seniorRatio; // in bps
    uint256 juniorDeposits;
    uint256 seniorDeposits;
    uint256 totalDeposits;
  }

  mapping(address => bool) public authorizedPools;
  mapping(address => mapping(address => TrancheConfig)) public poolConfigs;
  address[] public poolList;

  uint256 public constant RATIO_DENOMINATOR = 10000;

  event PoolAdded(address indexed pool, address indexed asset, address vault);
  event Deposited(address indexed user, address indexed asset, uint256 amount, address pool);
  event Withdrawn(address indexed user, address indexed asset, uint256 amount, address pool);
  event LiquidityRequested(address indexed pool, address indexed asset, uint256 amount);
  event BadDebtCovered(address indexed pool, address indexed asset, uint256 amount);
  event DebtRepaid(address indexed pool, address indexed asset, uint256 amount);

  modifier onlyAuthorizedPool() {
    require(authorizedPools[msg.sender], 'Unauthorized pool');
    _;
  }

  /// @notice Constructor to initialize the contract with asset and split configuration.
  /// @param _asset The underlying ERC20 asset address.
  /// @param _juniorRatio The junior ratio (in basis points).
  /// @param _seniorRatio The senior ratio (in basis points); must add up to RATIO_DENOMINATOR.
  constructor(address _asset, uint256 _juniorRatio, uint256 _seniorRatio) Ownable(msg.sender) {
    require(_juniorRatio + _seniorRatio == RATIO_DENOMINATOR, 'Invalid split config');
    // owner = msg.sender;
  }

  // --- Admin Functions ---

  function linkVaultToPool(
    address asset,
    address pool,
    address vault,
    uint256 juniorRatio
  ) external onlyOwner {
    require(juniorRatio <= 10000, 'Invalid ratio');
    require(!authorizedPools[pool], 'Pool already added');
    authorizedPools[pool] = true;
    poolList.push(pool);

    poolConfigs[asset][pool] = TrancheConfig({
      vault: vault,
      juniorRatio: juniorRatio,
      seniorRatio: 10000 - juniorRatio,
      juniorDeposits: 0,
      seniorDeposits: 0,
      totalDeposits: 0,
      outstandingDebt: 0
    });

    emit PoolAdded(pool, asset, vault);
  }

  // --- Core Functions ---

  /// @notice Deposits funds, splitting them between the selected pool (junior tranche) and the vault (senior tranche).
  function deposit(address asset, uint256 amount, address pool) external {
    TrancheConfig storage config = poolConfigs[asset][pool];
    require(authorizedPools[pool], 'Pool not accepted');
    require(config.vault != address(0), 'Vault not set');
    require(amount > 0, 'Amount must be greater than zero');

    // Transfer funds from depositor to this contract.
    require(IERC20(asset).transferFrom(msg.sender, address(this), amount), 'Transfer failed');

    // 1. Debt repayment
    uint256 repayment = Math.min(amount, config.outstandingDebt);
    if (repayment > 0) {
      _repayDebt(asset, pool, repayment);
      amount -= repayment;
    }

    if (amount == 0) return;

    // 2. Split and deposit remaining
    uint256 juniorAmount = amount.mulDiv(config.juniorRatio, RATIO_DENOMINATOR);
    uint256 seniorAmount = amount - juniorAmount;

    _depositJunior(asset, pool, juniorAmount);
    _depositSenior(asset, pool, seniorAmount);

    config.totalDeposits += amount;

    emit Deposited(msg.sender, asset, amount, pool);
  }

  /// @notice Withdraws funds, coordinating withdrawal from both the pool and the vault.
  /// @param amount The total withdrawal amount.
  /// @param pool The pool address to use for the junior tranche.
  function withdraw(address asset, uint256 amount, address pool) external {
    TrancheConfig storage config = poolConfigs[asset][pool];
    require(authorizedPools[pool], 'Pool not accepted');
    require(amount > 0, 'Amount must be greater than zero');
    require(amount <= config.totalDeposits, 'Withdrawal exceeds total deposits');

    // Calculate split amounts.
    uint256 juniorAmount = (amount * config.juniorRatio) / RATIO_DENOMINATOR;
    uint256 seniorAmount = amount - juniorAmount;

    // Check available senior liquidity (deposits - debt)
    uint256 availableSenior = config.seniorDeposits - config.outstandingDebt;
    require(seniorAmount <= availableSenior, 'Insufficient senior liquidity');

    _withdrawJunior(asset, pool, juniorAmount);
    _withdrawSenior(asset, pool, seniorAmount);

    config.totalDeposits -= amount;

    emit Withdrawn(msg.sender, asset, amount, pool);
  }

  // function requestLiquidity(address pool, address asset, uint256 requiredAmount) external {
  //   TrancheConfig storage config = poolConfigs[asset][pool];
  //   if (config.vault == address(0)) revert();

  //   uint256 availableJunior = IERC20(asset).balanceOf(pool);
  //   if (availableJunior >= requiredAmount) return;

  //   uint256 deficit = requiredAmount - availableJunior;
  //   _rebalanceFromVault(config, asset, deficit);
  // }

  // -- hooks --
  // Called by pool before any liquidity-out operation
  function beforeLiquidityOperation(
    address asset,
    uint256 requiredAmount
  ) external onlyAuthorizedPool {
    TrancheConfig storage config = poolConfigs[asset][msg.sender];
    // uint256 currentLiquidity = IERC20(asset).balanceOf(msg.sender);
    (uint availableLiquidity, , ) = getReserveData(asset);

    if (availableLiquidity < requiredAmount) {
      if (config.seniorDeposits > requiredAmount) {
        uint256 deficit = requiredAmount - availableLiquidity;
        _pullFromVault(config, asset, deficit);
      } else {
        uint256 deficit = requiredAmount - config.seniorDeposits;
        _borrowFromVault(asset, msg.sender, deficit);
      }
    }
  }

  // Called by pool after any debt-changing operation
  function afterDebtOperation(address asset) external onlyAuthorizedPool {
    (uint availableLiquidity, uint totalVariableDebt, uint totalStableDebt) = getReserveData(asset);
    uint256 totalDebt = totalStableDebt + totalVariableDebt;
    if (availableLiquidity < totalDebt) {
      uint256 badDebt = totalDebt - availableLiquidity;
      _coverBadDebt(asset, badDebt);
    }
  }

  function getReserveData(address asset) private returns (uint, uint, uint) {
    DataTypes.ReserveDataLegacy memory reserveData = IPool(msg.sender).getReserveData(asset);
    uint256 availableLiquidity = IERC20(asset).balanceOf(reserveData.aTokenAddress);
    uint totalScaledVariableDebt = IVariableDebtToken(reserveData.variableDebtTokenAddress)
      .scaledTotalSupply();

    return (availableLiquidity, totalScaledVariableDebt, 0);
  }

  // Debt repayment logic
  function _repayDebt(address asset, address pool, uint256 amount) private {
    TrancheConfig storage config = poolConfigs[asset][pool];
    uint256 repayAmount = Math.min(amount, config.outstandingDebt);
    config.outstandingDebt -= amount;
    // IERC20(asset).approve(config.vault, amount);
    // IVault(config.vault).stake(asset, msg.sender, amount); // Return to vault

    if (amount > repayAmount) {
      config.seniorDeposits += amount - repayAmount;
    }
    emit DebtRepaid(pool, asset, amount);
  }

  // Borrow from vault (senior tranche)
  function _borrowFromVault(address asset, address pool, uint256 deficit) private {
    TrancheConfig storage config = poolConfigs[asset][pool];
    uint256 vaultBalance = IERC20(asset).balanceOf(config.vault);
    uint256 borrowAmount = Math.min(deficit, vaultBalance);

    if (borrowAmount > 0) {
      IVault(config.vault).emergencyWithdraw(asset, borrowAmount);
      IERC20(asset).safeTransfer(pool, borrowAmount);
      config.outstandingDebt += borrowAmount;
      config.seniorDeposits = 0;
      // emit LiquidityBorrowed(pool, asset, borrowAmount);
    }
  }

  // Internal deposit/withdraw helpers
  function _depositJunior(address asset, address pool, uint256 amount) private {
    IERC20(asset).approve(pool, amount);
    IPool(pool).supply(asset, amount, msg.sender, 0);
    poolConfigs[asset][pool].juniorDeposits += amount;
  }

  function _depositSenior(address asset, address pool, uint256 amount) private {
    TrancheConfig storage config = poolConfigs[asset][pool];
    IERC20(asset).approve(config.vault, amount);
    IVault(config.vault).stake(asset, msg.sender, amount);
    // config.seniorDeposits += amount;
  }

  function _withdrawJunior(address asset, address pool, uint256 amount) private {
    IPool(pool).withdraw(asset, amount, msg.sender);
    poolConfigs[asset][pool].juniorDeposits -= amount;
  }

  function _withdrawSenior(address asset, address pool, uint256 amount) private {
    TrancheConfig storage config = poolConfigs[asset][pool];
    IVault(config.vault).redeem(asset, msg.sender, amount);
    config.seniorDeposits -= amount;
  }

  // --- Rebalancing Logic ---

  /// @notice Rebalances funds by transferring from the vault (senior tranche) to the pool (junior tranche)
  /// if the junior balance is below its expected share based on the configured split.
  function _pullFromVault(TrancheConfig storage config, address asset, uint256 deficit) internal {
    uint256 vaultBalance = IERC20(asset).balanceOf(config.vault);
    uint256 pullAmount = deficit > vaultBalance ? vaultBalance : deficit;

    IVault(config.vault).emergencyWithdraw(asset, pullAmount);
    IERC20(asset).safeTransfer(msg.sender, pullAmount);

    config.juniorDeposits += pullAmount;
    config.seniorDeposits -= pullAmount;

    emit LiquidityRequested(msg.sender, asset, pullAmount);
  }

  function _coverBadDebt(address asset, uint256 badDebt) internal {
    TrancheConfig storage config = poolConfigs[asset][msg.sender];
    uint256 pullAmount = (badDebt * config.seniorRatio) / 10000;
    uint256 vaultBalance = IERC20(asset).balanceOf(config.vault);
    uint256 coverAmount = pullAmount > vaultBalance ? vaultBalance : pullAmount;

    IVault(config.vault).emergencyWithdraw(asset, coverAmount);
    IERC20(asset).safeTransfer(msg.sender, coverAmount);

    config.seniorDeposits -= coverAmount;
    emit BadDebtCovered(msg.sender, asset, coverAmount);
  }
}
