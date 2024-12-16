// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

// Interfaces for external protocols
interface ILendingPool {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external returns (uint256);
  function getUserAccountData(
    address user
  )
    external
    view
    returns (
      uint256 totalCollateralETH,
      uint256 totalDebtETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );
}

interface IAaveOracle {
  function getAssetPrice(address asset) external view returns (uint256);
}

interface ISwapController {
  function swap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOutMinimum,
    uint24 poolFee
  ) external returns (uint256 amountOut);

  function getQuote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint24 poolFee
  ) external view returns (uint256 expectedAmountOut);
}

/**
 * @title Advanced Multi-Asset Leveraged Loop Strategy
 * @notice Implements a flexible leveraged strategy with multi-asset support and swap capabilities
 */
contract AdvancedLoopStrategy is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Configuration constants
  uint256 public constant SAFE_BUFFER = 10; // wei buffer for calculations
  uint256 public constant VARIABLE_RATE_MODE = 2;
  uint256 public constant BASIS_POINTS = 10000; // For percentage calculations

  // Protocol interfaces
  IPool public immutable lendingPool;
  ISwapController public swapController;

  // Strategy parameters
  uint256 public targetLeverageMultiplier;
  uint24 public swapPoolFee;
  uint256 public maxIterations = 15;

  // Events
  event PositionEntered(uint256 initialCollateral, uint256 iterations);
  event PositionExited(uint256 withdrawnAmount);
  event LeverageParametersUpdated(uint256 leverage, uint256 maxLTV);
  event AssetSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

  constructor(
    address _owner,
    address _lendingPool,
    address _swapController,
    uint24 _swapPoolFee
  ) Ownable(_owner) {
    require(_lendingPool != address(0), 'Invalid lending pool');
    // require(_priceOracle != address(0), 'Invalid price oracle');
    require(_swapController != address(0), 'Invalid swap controller');

    lendingPool = IPool(_lendingPool);
    // priceOracle = IAaveOracle(_priceOracle);
    swapController = ISwapController(_swapController);

    targetLeverageMultiplier = 1;
    swapPoolFee = _swapPoolFee;
  }

  /**
   * @notice Calculate max safe iterations based on protocol LTV constraints
   * @return Optimal number of leverage iterations
   */
  function calculateMaxSafeIterations(address collateralAsset) public view returns (uint256) {
    uint256 maxLTV = _getMaxLTVForAsset(address(collateralAsset));
    uint256 currentLTV = getCurrentLTV();
    uint256 iterationBuffer = 500; // 5% buffer

    // Prevent division by zero and ensure we can leverage
    if (maxLTV <= currentLTV || targetLeverageMultiplier == 0) return 0;

    uint256 remainingLTV = maxLTV - currentLTV - iterationBuffer;
    uint256 leverageStep = (currentLTV * targetLeverageMultiplier) / BASIS_POINTS;

    uint256 maxCalculatedIterations = remainingLTV / leverageStep;
    return maxCalculatedIterations > maxIterations ? maxIterations : maxCalculatedIterations; // Use new variable name
  }

  /**
   * @notice Enter leveraged position with advanced multi-asset strategy
   * @param initialCollateral Initial collateral amount
   * @param iterations Number of leverage iterations
   */
  function enterPosition(
    address collateralAsset,
    address borrowAsset,
    address priceOracle,
    uint256 initialCollateral,
    uint256 iterations
  ) external nonReentrant onlyOwner {
    require(iterations <= maxIterations, 'Exceeded max iterations');

    // Transfer initial collateral
    IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), initialCollateral);

    // Initial deposit
    _depositCollateral(collateralAsset, initialCollateral);

    // Leverage loop
    for (uint256 i = 0; i < iterations; i++) {
      uint256 borrowAmount = _calculateOptimalBorrowAmount(
        collateralAsset,
        borrowAsset,
        priceOracle
      );
      _borrowAndSwap(collateralAsset, borrowAsset, priceOracle, borrowAmount);
    }

    emit PositionEntered(initialCollateral, iterations);
  }

  /**
   * @notice Calculate optimal borrow amount based on current position
   * @return Optimal borrow amount
   */
  function _calculateOptimalBorrowAmount(
    address collateralAsset,
    address borrowAsset,
    address priceOracle
  ) internal view returns (uint256) {
    (, , uint256 availableBorrowsETH, , , ) = lendingPool.getUserAccountData(address(this));
    uint256 assetPrice = IAaveOracle(priceOracle).getAssetPrice(address(borrowAsset));

    return (availableBorrowsETH * (10 ** ERC20(borrowAsset).decimals())) / assetPrice;
  }

  /**
   * @notice Borrow and swap borrowed assets
   * @param borrowAmount Amount to borrow
   */
  function _borrowAndSwap(
    address collateralAsset,
    address borrowAsset,
    address priceOracle,
    uint256 borrowAmount
  ) internal {
    // Borrow assets
    lendingPool.borrow(address(borrowAsset), borrowAmount, VARIABLE_RATE_MODE, 0, address(this));

    // Swap borrowed assets back to collateral
    uint256 amountOut = swapController.swap(
      address(borrowAsset),
      address(collateralAsset),
      borrowAmount,
      (9500 * borrowAmount) / BASIS_POINTS, //5% slippage
      swapPoolFee
    );

    // Deposit swapped assets
    _depositCollateral(collateralAsset, amountOut);

    emit AssetSwapped(address(borrowAsset), address(collateralAsset), borrowAmount, amountOut);
  }

  /**
   * @notice Deposit collateral to lending pool
   * @param amount Collateral amount to deposit
   */
  function _depositCollateral(address collateralAsset, uint256 amount) internal {
    IERC20(collateralAsset).safeIncreaseAllowance(address(lendingPool), amount);
    lendingPool.deposit(address(collateralAsset), amount, address(this), 0);
  }

  /**
   * @notice Exit entire position
   */
  function exitPosition(
    address collateralAsset,
    address borrowAsset,
    address priceOracle
  ) external nonReentrant onlyOwner {
    uint256 totalWithdrawn = _unwindPosition(collateralAsset, borrowAsset, priceOracle);
    emit PositionExited(totalWithdrawn);
  }

  /**
   * @notice Unwind entire leveraged position
   * @return Total amount withdrawn
   */
  function _unwindPosition(
    address collateralAsset,
    address borrowAsset,
    address priceOracle
  ) internal returns (uint256) {
    uint256 totalWithdrawn;

    // Repay and withdraw loop
    while (getCurrentLTV() > 0) {
      uint256 borrowBalance = getCurrentBorrowBalance(borrowAsset, priceOracle);
      uint256 withdrawAmount = _calculateWithdrawalAmount(borrowBalance);

      // Withdraw collateral
      lendingPool.withdraw(address(collateralAsset), withdrawAmount, address(this));

      // Swap back to borrow asset if needed
      if (address(collateralAsset) != address(borrowAsset)) {
        swapController.swap(
          address(collateralAsset),
          address(borrowAsset),
          withdrawAmount,
          (9500 * withdrawAmount) / BASIS_POINTS, // 5% slippage
          // 0,
          swapPoolFee
        );
      }

      // Repay borrow
      IERC20(borrowAsset).safeIncreaseAllowance(address(lendingPool), borrowBalance);
      lendingPool.repay(address(borrowAsset), borrowBalance, VARIABLE_RATE_MODE, address(this));

      totalWithdrawn += withdrawAmount;
    }

    // Final withdrawal of any remaining balance
    uint256 finalBalance = IERC20(collateralAsset).balanceOf(address(this));
    IERC20(collateralAsset).safeTransfer(owner(), finalBalance);
    totalWithdrawn += finalBalance;

    return totalWithdrawn;
  }

  /**
   * @notice Calculate withdrawal amount based on current borrow balance
   * @param borrowBalance Current borrow balance
   * @return Amount to withdraw
   */
  function _calculateWithdrawalAmount(uint256 borrowBalance) internal view returns (uint256) {
    return (borrowBalance * (BASIS_POINTS + 100)) / BASIS_POINTS; // Add small buffer
  }

  /**
   * @notice Extract max LTV from reserve configuration
   * @param asset Asset address to check
   * @return Max LTV in basis points
   */
  function _getMaxLTVForAsset(address asset) internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = lendingPool.getConfiguration(asset);

    // Correctly extract LTV using bit manipulation
    uint256 ltv = (configuration.data >> 16) & 0xffff;
    return ltv;
  }

  /**
   * @notice Get current Loan-to-Value ratio
   * @return Current LTV percentage
   */
  function getCurrentLTV() public view returns (uint256) {
    (, , , , uint256 ltv, ) = lendingPool.getUserAccountData(address(this));
    return ltv;
  }

  /**
   * @notice Get current borrow balance
   * @return Current borrow balance
   */
  function getCurrentBorrowBalance(
    address borrowAsset,
    address priceOracle
  ) public view returns (uint256) {
    (, uint256 totalDebtETH, , , , ) = lendingPool.getUserAccountData(address(this));
    uint256 assetPrice = IAaveOracle(priceOracle).getAssetPrice(address(borrowAsset));
    return (totalDebtETH * (10 ** ERC20(borrowAsset).decimals())) / assetPrice;
  }

  /**
   * @notice Update leverage parameters
   * @param _newLeverageMultiplier New leverage multiplier
   * @param _newMaxIteration New maximum leverage
   */
  function updateLeverageParameters(
    uint256 _newLeverageMultiplier,
    uint256 _newMaxIteration
  ) external onlyOwner {
    require(_newLeverageMultiplier > 0, 'Invalid leverage');

    targetLeverageMultiplier = _newLeverageMultiplier;
    maxIterations = _newMaxIteration;

    emit LeverageParametersUpdated(_newLeverageMultiplier, _newMaxIteration);
  }

  /**
   * @notice Update swap controller
   * @param _newSwapController New swap controller address
   */
  function updateSwapController(address _newSwapController) external onlyOwner {
    require(_newSwapController != address(0), 'Invalid swap controller');
    swapController = ISwapController(_newSwapController);
  }
}
