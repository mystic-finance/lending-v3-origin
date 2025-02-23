// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {ReserveConfiguration} from 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

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
  ) external returns (uint256 expectedAmountOut);
}

/**
 * @title Advanced Multi-Asset Leveraged Loop Strategy
 * @notice Implements a flexible leveraged strategy with multi-asset support and swap capabilities
 */
contract AdvancedLoopStrategy is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  // structs
  struct Position {
    address user;
    address collateralAsset;
    address borrowAsset;
    uint256 collateralBalance;
    uint256 borrowBalance;
    bool isActive;
  }

  // Configuration constants
  uint256 public constant SAFE_BUFFER = 50; // 0.5% safety margin
  uint256 public constant VARIABLE_RATE_MODE = 2;
  uint256 public constant BASIS_POINTS = 10000;
  uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;
  uint256 public constant MAX_SLIPPAGE = 500; // 5% maximum slippage

  // Protocol interfaces
  IPool public immutable lendingPool;
  ISwapController public swapController;
  IAaveOracle public aaveOracle;

  // Strategy parameters
  uint256 public targetLeverageMultiplier;
  uint24 public swapPoolFee;
  uint256 public maxIterations = 15;
  uint256 private nextPositionId = 1;

  // User position tracking
  mapping(uint256 => Position) public positions;
  mapping(address => uint256[]) private userPositions;

  // Events
  event PositionEntered(
    uint256 indexed positionId,
    address indexed user,
    address collateralAsset,
    address borrowAsset,
    uint256 initialCollateral,
    uint256 iterations
  );
  event PositionExited(
    uint256 indexed positionId,
    address indexed user,
    address collateralAsset,
    address borrowAsset,
    uint256 withdrawnAmount
  );
  event LeverageParametersUpdated(uint256 leverage, uint256 maxIterations);
  event AssetSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

  constructor(
    address _owner,
    address _lendingPool,
    address _swapController,
    uint24 _swapPoolFee
  ) Ownable(_owner) {
    require(_lendingPool != address(0), 'Invalid lending pool');
    require(_swapPoolFee > 0 && _swapPoolFee <= 10000, 'Invalid pool fee');
    require(_swapController != address(0), 'Invalid swap controller');

    lendingPool = IPool(_lendingPool);
    swapController = ISwapController(_swapController);
    aaveOracle = IAaveOracle((lendingPool.ADDRESSES_PROVIDER()).getPriceOracle());
    swapPoolFee = _swapPoolFee;
    targetLeverageMultiplier = 1;
    maxIterations = 15;
  }

  function calculateMaxSafeIterations(
    address collateralAsset,
    address borrowAsset
  ) public view returns (uint256) {
    uint256 maxLTV = _getMaxLTVForAsset(collateralAsset);
    uint256 currentLTV = getCurrentLTV(msg.sender);
    uint256 iterationBuffer = 500; // 5% buffer

    if (maxLTV <= currentLTV + iterationBuffer || targetLeverageMultiplier < 1) {
      return 0;
    }

    (, , , , , uint256 healthFactor) = lendingPool.getUserAccountData(msg.sender);
    if (healthFactor < MIN_HEALTH_FACTOR) {
      return 0;
    }

    uint256 remainingLTV = maxLTV - currentLTV - iterationBuffer;
    // uint256 leverageStep = (currentLTV * (targetLeverageMultiplier - 1)) / BASIS_POINTS;

    // if (leverageStep == 0) return 0;

    uint256 calculatedIterations = BASIS_POINTS / (BASIS_POINTS - remainingLTV);
    require(calculatedIterations > 0, 'iteration must be greater than 0');
    return calculatedIterations > maxIterations ? maxIterations : calculatedIterations;
  }

  function enterPosition(
    address collateralAsset,
    address borrowAsset,
    uint256 initialCollateral,
    uint256 iterations
  ) external nonReentrant {
    require(initialCollateral > 0, 'Invalid collateral amount');
    require(iterations > 0 && iterations <= maxIterations, 'Invalid iterations');
    require(collateralAsset != borrowAsset, 'Assets must be different');

    uint256 maxSafeIterations = calculateMaxSafeIterations(collateralAsset, borrowAsset);
    require(iterations <= maxSafeIterations, 'Exceeds safe iterations');
    uint256 positionId = nextPositionId++;

    // Transfer initial collateral
    IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), initialCollateral);

    // Initial deposit
    _depositCollateral(collateralAsset, initialCollateral);

    positions[positionId] = Position({
      user: msg.sender,
      collateralAsset: collateralAsset,
      borrowAsset: borrowAsset,
      collateralBalance: initialCollateral,
      borrowBalance: 0,
      isActive: true
    });
    userPositions[msg.sender].push(positionId);

    uint256 totalBorrowed = 0;
    Position storage position = positions[positionId];

    for (uint256 i = 0; i < iterations; ) {
      (, , , , , uint256 healthFactor) = lendingPool.getUserAccountData(msg.sender);
      require(healthFactor >= MIN_HEALTH_FACTOR, 'Health factor too low');

      uint256 borrowAmount = _calculateOptimalBorrowAmount(collateralAsset, borrowAsset);
      // if (borrowAmount == 0) break;

      uint256 swappedAmount = _borrowAndSwap(collateralAsset, borrowAsset, borrowAmount);

      totalBorrowed += borrowAmount;
      position.borrowBalance += borrowAmount;
      position.collateralBalance += swappedAmount;

      unchecked {
        ++i;
      }
    }

    emit PositionEntered(
      positionId,
      msg.sender,
      collateralAsset,
      borrowAsset,
      initialCollateral,
      maxSafeIterations
    );
  }

  function _calculateOptimalBorrowAmount(
    address collateralAsset,
    address borrowAsset
  ) internal view returns (uint256) {
    (, , uint256 availableBorrowsETH, , , ) = lendingPool.getUserAccountData(msg.sender); // in deicmal 18
    if (availableBorrowsETH == 0) return 0;

    uint256 assetPrice = IAaveOracle(aaveOracle).getAssetPrice(borrowAsset);
    uint256 borrowDecimals = IERC20Metadata(borrowAsset).decimals();
    require(assetPrice > 0, 'Invalid asset price');

    // return (availableBorrowsETH) / (assetPrice * 1e8);
    return (availableBorrowsETH * 10 ** borrowDecimals * 1e8) / (assetPrice * 1e8);
  }

  function _borrowAndSwap(
    address collateralAsset,
    address borrowAsset,
    uint256 borrowAmount
  ) internal returns (uint256) {
    require(borrowAmount > 0, 'Invalid borrow amount');

    uint256 expectedAmountOut = swapController.getQuote(
      borrowAsset,
      collateralAsset,
      borrowAmount,
      swapPoolFee
    );
    require(expectedAmountOut > 0, 'Invalid swap quote');

    lendingPool.borrow(borrowAsset, borrowAmount, VARIABLE_RATE_MODE, 0, msg.sender);

    uint256 minAmountOut = (expectedAmountOut * (BASIS_POINTS - MAX_SLIPPAGE)) / BASIS_POINTS;

    IERC20(borrowAsset).approve(address(swapController), 0); // Reset approval
    IERC20(borrowAsset).approve(address(swapController), borrowAmount);

    uint256 amountOut = swapController.swap(
      borrowAsset,
      collateralAsset,
      borrowAmount,
      minAmountOut,
      swapPoolFee
    );

    _depositCollateral(collateralAsset, amountOut);

    emit AssetSwapped(borrowAsset, collateralAsset, borrowAmount, amountOut);
    return amountOut;
  }

  function _depositCollateral(address collateralAsset, uint256 amount) internal {
    IERC20(collateralAsset).approve(address(lendingPool), 0); // Reset approval
    IERC20(collateralAsset).approve(address(lendingPool), amount);
    lendingPool.deposit(collateralAsset, amount, msg.sender, 0);
  }

  function exitPosition(uint256 positionId) external nonReentrant {
    Position storage position = positions[positionId];
    require(position.isActive, 'Position not active');
    require(position.user == msg.sender, 'Not position owner');
    require(
      position.collateralBalance > 0 && position.borrowBalance > 0,
      'position exited already'
    );
    uint256 totalWithdrawn = _unwindPosition(positionId);

    // Clear user balances
    position.isActive = false;
    _removeUserPosition(position.user, positionId);

    emit PositionExited(
      positionId,
      msg.sender,
      position.collateralAsset,
      position.borrowAsset,
      totalWithdrawn
    );
  }

  function _removeUserPosition(address user, uint256 positionId) internal {
    uint256[] storage userPos = userPositions[user];
    for (uint256 i = 0; i < userPos.length; i++) {
      if (userPos[i] == positionId) {
        userPos[i] = userPos[userPos.length - 1];
        userPos.pop();
        break;
      }
    }
  }

  function calculateWithdrawableCollateral(
    address user,
    address collateralAsset,
    address borrowAsset
  ) public view returns (uint256) {
    (
      uint256 totalCollateralETH,
      uint256 totalDebtETH,
      uint256 availableBorrowsETH,
      ,
      ,
      uint256 healthFactor
    ) = lendingPool.getUserAccountData(user);
    require(healthFactor > MIN_HEALTH_FACTOR, 'Health factor too low to withdraw');

    uint256 assetPrice = aaveOracle.getAssetPrice(collateralAsset);
    require(assetPrice > 0, 'Invalid asset price');

    // totalDebtETH =
    //   (totalDebtETH * (10 ** ERC20(collateralAsset).decimals())) /
    //   (10 ** ERC20(borrowAsset).decimals());

    // uint256 maxWithdrawETH = totalCollateralETH - totalDebtETH - SAFE_BUFFER;
    uint256 maxWithdrawCollateral = (availableBorrowsETH *
      10 ** (ERC20(collateralAsset).decimals()) *
      1e8) / (assetPrice * 1e8);

    return maxWithdrawCollateral; //amountToWithdraw > maxWithdrawCollateral ? maxWithdrawCollateral : amountToWithdraw;
  }

  function _unwindPosition(uint256 positionId) internal returns (uint256) {
    uint256 totalWithdrawn = 0;
    Position storage position = positions[positionId];
    address collateralAsset = position.collateralAsset;
    address borrowAsset = position.borrowAsset;
    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(collateralAsset);

    while (true) {
      uint256 currentDebt = getCurrentDebtBalance(borrowAsset);
      if (currentDebt == 0) break;

      uint256 withdrawableCollateral = calculateWithdrawableCollateral(
        msg.sender,
        collateralAsset,
        borrowAsset
      );
      if (withdrawableCollateral == 0) break;

      // Withdraw collateral
      IERC20(reserveData.aTokenAddress).transferFrom(
        msg.sender,
        address(this),
        withdrawableCollateral
      );
      uint256 actualWithdrawn = lendingPool.withdraw(
        collateralAsset,
        withdrawableCollateral,
        address(this)
      );

      // Swap collateral to repay borrow asset if necessary
      uint256 repayAmount = actualWithdrawn;
      if (collateralAsset != borrowAsset) {
        IERC20(collateralAsset).approve(address(swapController), actualWithdrawn);
        repayAmount = swapController.swap(
          collateralAsset,
          borrowAsset,
          actualWithdrawn,
          (actualWithdrawn * (BASIS_POINTS - MAX_SLIPPAGE)) / BASIS_POINTS,
          swapPoolFee
        );
      }

      // Repay debt
      IERC20(borrowAsset).approve(address(lendingPool), repayAmount);
      uint repaidAmount = lendingPool.repay(
        borrowAsset,
        repayAmount,
        VARIABLE_RATE_MODE,
        msg.sender
      );

      totalWithdrawn += actualWithdrawn;

      // Update user balances
      position.collateralBalance = position.collateralBalance > actualWithdrawn
        ? position.collateralBalance - actualWithdrawn
        : 0;
      position.borrowBalance = position.borrowBalance > repayAmount
        ? position.borrowBalance - repayAmount
        : 0;
    }

    // Withdraw any remaining collateral
    uint256 finalCollateralBalance = IERC20(reserveData.aTokenAddress).balanceOf(msg.sender);
    if (finalCollateralBalance > 0) {
      IERC20(reserveData.aTokenAddress).transferFrom(
        msg.sender,
        address(this),
        finalCollateralBalance
      );
      totalWithdrawn += finalCollateralBalance;
    }

    // withdraw max possible collateral
    lendingPool.withdraw(collateralAsset, type(uint256).max, address(this));

    uint256 finalAssetBalance = IERC20(borrowAsset).balanceOf(address(this));
    if (finalAssetBalance > 0) {
      IERC20(borrowAsset).approve(address(swapController), finalAssetBalance);
      swapController.swap(borrowAsset, collateralAsset, finalAssetBalance, 0, swapPoolFee);
    }

    // collateral asset could still be left after final repay and needs swapp and withdrawal
    uint256 finalBalance = IERC20(collateralAsset).balanceOf(address(this));
    if (finalBalance > 0) {
      IERC20(collateralAsset).safeTransfer(msg.sender, finalBalance);
    }

    return totalWithdrawn;
  }
  function _calculateWithdrawalAmount(uint256 borrowBalance) internal pure returns (uint256) {
    return (borrowBalance * (BASIS_POINTS + SAFE_BUFFER)) / BASIS_POINTS;
  }

  function _getMaxLTVForAsset(address asset) internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = lendingPool.getConfiguration(asset);
    return configuration.getLtv();
  }

  function getCurrentLTV(address user) public view returns (uint256) {
    (, , , , uint256 ltv, ) = lendingPool.getUserAccountData(user);
    return ltv;
  }

  function getCurrentBorrowBalance(address borrowAsset) public view returns (uint256) {
    (, uint256 totalDebtETH, uint256 availableBorrowsETH, , , ) = lendingPool.getUserAccountData(
      msg.sender
    );
    uint256 assetPrice = IAaveOracle(aaveOracle).getAssetPrice(borrowAsset);
    require(assetPrice > 0, 'Invalid asset price');
    return (availableBorrowsETH * (10 ** ERC20(borrowAsset).decimals()) * 1e8) / (assetPrice * 1e8); // borrow base * decimal power / (assetPriceOracle/1e8) / 1e8 (oracle from base)
    // return (availableBorrowsETH ) / (assetPrice * 1e8);
  }

  function getCurrentDebtBalance(address borrowAsset) public view returns (uint256) {
    (, uint256 totalDebtETH, uint256 availableBorrowsETH, , , ) = lendingPool.getUserAccountData(
      msg.sender
    );
    uint256 assetPrice = IAaveOracle(aaveOracle).getAssetPrice(borrowAsset);
    require(assetPrice > 0, 'Invalid asset price');
    return (totalDebtETH * (10 ** ERC20(borrowAsset).decimals()) * 1e8) / (assetPrice * 1e8);
    // return (availableBorrowsETH * (10 ** ERC20(borrowAsset).decimals())) / assetPrice;
  }

  function updateLeverageParameters(
    uint256 _newLeverageMultiplier,
    uint256 _newMaxIterations
  ) external onlyOwner {
    require(_newLeverageMultiplier > 0, 'Invalid leverage');
    require(_newMaxIterations > 0, 'Invalid max iterations');

    targetLeverageMultiplier = _newLeverageMultiplier;
    maxIterations = _newMaxIterations;

    emit LeverageParametersUpdated(_newLeverageMultiplier, _newMaxIterations);
  }

  function updateSwapController(address _newSwapController) external onlyOwner {
    require(_newSwapController != address(0), 'Invalid swap controller');
    swapController = ISwapController(_newSwapController);
  }

  function updateSwapFee(uint24 _swapFee) external onlyOwner {
    swapPoolFee = _swapFee;
  }

  function getUserPositions(address user) external view returns (uint256[] memory) {
    return userPositions[user];
  }

  function getUserActivePositionIds(address user) external view returns (uint256[] memory) {
    uint256[] memory positionIds = userPositions[user];
    uint256 activeCount = 0;

    // Count active positions
    for (uint256 i = 0; i < positionIds.length; i++) {
      if (positions[positionIds[i]].isActive) {
        activeCount++;
      }
    }

    // Create array of active positions
    uint256[] memory activePositions = new uint256[](activeCount);
    uint256 currentIndex = 0;

    for (uint256 i = 0; i < positionIds.length; i++) {
      if (positions[positionIds[i]].isActive) {
        activePositions[currentIndex] = positionIds[i];
        currentIndex++;
      }
    }

    return activePositions;
  }
}
