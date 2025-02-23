// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {ReserveConfiguration} from 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {DataTypes} from 'src/core/contracts/protocol/libraries/types/DataTypes.sol';
import {IAaveOracle} from 'src/core/contracts/interfaces/IAaveOracle.sol';

// Interfaces for Controllers
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

interface IFlashLoanProvider {
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external;

  function getMaxFlashLoanAmount(address asset) external view returns (uint256);
  function getFlashLoanFee(address asset, uint256 amount) external view returns (uint256);
}

interface IFlashLoanController {
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external;
  function currentProvider() external returns (IFlashLoanProvider provider);
}

// Existing interfaces
interface ILendingPool {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;
  function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
  function getConfiguration(address asset) external view returns (uint256);
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

interface IFlashLoanReceiver {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}

contract LeveragedBorrowingVault is Ownable, ReentrancyGuard, IFlashLoanReceiver {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  // Structs
  struct UserPosition {
    address user;
    address collateralToken;
    address borrowToken;
    uint256 initialCollateral;
    uint256 totalCollateral;
    uint256 totalBorrowed;
    uint256 leverageMultiplier;
    bool isActive;
  }

  struct OperationParams {
    uint256 positionId;
    address user;
    address collateralToken;
    address borrowToken;
    uint256 initialCollateral;
    uint256 leverageMultiplier;
    address flashLoanController;
    address strategy;
    uint8 openPosition; // 0 for open, 1 for close, 2 for update
  }

  // Constants
  uint256 public constant MAX_LEVERAGE = 20;
  uint256 public constant SLIPPAGE_TOLERANCE = 50; // 0.5%
  uint16 public constant REFERRAL_CODE = 0;
  uint24 public DEFAULT_POOL_FEE = 50; // 0.5% pool fee
  uint256 private nextPositionId = 1;

  // External Contracts
  IPool public lendingPool;
  ISwapController public swapController;
  IFlashLoanController public flashLoanController;
  IAaveOracle aaveOracle;

  // Mappings
  // mapping(address => mapping(address => UserPosition)) public userPositions; // caller -> borrowToken -> position
  mapping(uint256 => UserPosition) public positions; // positionId -> position
  mapping(address => uint256[]) public userPositions; // user -> array of position IDs
  mapping(address => bool) public allowedCollateralTokens;
  mapping(address => bool) public allowedBorrowTokens;

  // Events
  event LeveragePositionOpened(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 initialAmount,
    uint256 leverageMultiplier
  );
  event LeveragePositionClosed(
    uint256 indexed positionId,
    address indexed user,
    uint256 collateralReturned
  );

  event LeveragePositionAdded(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 addedCollateral,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );

  event LeveragePositionRemoved(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 removedCollateral,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );

  event LeveragePositionLeverageUpdated(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 oldLeverageMultiplier,
    uint256 newLeverageMultiplier,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );

  constructor(
    address _lendingPool,
    address _swapController,
    address _flashLoanController
  ) Ownable(msg.sender) {
    lendingPool = IPool(_lendingPool);
    swapController = ISwapController(_swapController);
    flashLoanController = IFlashLoanController(_flashLoanController);
    aaveOracle = IAaveOracle((lendingPool.ADDRESSES_PROVIDER()).getPriceOracle());
    require(address(aaveOracle) != address(0), 'Invalid oracle address');
  }

  modifier onlyAllowedTokens(address collateralToken, address borrowToken) {
    require(allowedCollateralTokens[collateralToken], 'Collateral token not allowed');
    require(allowedBorrowTokens[borrowToken], 'Borrow token not allowed');
    _;
  }

  // Main Leverage Position Function
  function openLeveragePosition(
    address collateralToken,
    address borrowToken,
    uint256 initialCollateral,
    uint256 leverageMultiplier
  ) external nonReentrant {
    require(allowedCollateralTokens[collateralToken], 'Collateral token not allowed');
    require(allowedBorrowTokens[borrowToken], 'Borrow token not allowed');
    require(leverageMultiplier > 1 && leverageMultiplier <= MAX_LEVERAGE, 'Invalid leverage');

    // Transfer initial collateral from user
    IERC20(collateralToken).transferFrom(msg.sender, address(this), initialCollateral);
    uint256 positionId = nextPositionId++;

    // Encode additional params for flash loan operation
    bytes memory params = abi.encode(
      OperationParams({
        positionId: positionId,
        user: msg.sender,
        collateralToken: collateralToken,
        borrowToken: borrowToken,
        initialCollateral: initialCollateral,
        leverageMultiplier: leverageMultiplier,
        flashLoanController: address(flashLoanController),
        strategy: address(this),
        openPosition: 0
      })
    );

    // Initiate flash loan
    uint256 expectedAmountIn = swapController.getQuote(
      collateralToken,
      borrowToken,
      initialCollateral * (leverageMultiplier - 1),
      DEFAULT_POOL_FEE // 0% buffer cause of flashloan
    );
    require(expectedAmountIn > 0, 'Invalid swap quote');

    flashLoanController.executeFlashLoan(borrowToken, expectedAmountIn, params);
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    require(msg.sender == address(flashLoanController), 'Unauthorized');
    require(assets.length == 1 && amounts.length == 1 && premiums.length == 1, 'Invalid arrays');
    require(initiator == address(flashLoanController.currentProvider()), 'Invalid initiator');

    OperationParams memory operationParams = abi.decode(params, (OperationParams));

    if (operationParams.openPosition == 0) {
      return _executeOpenPosition(assets[0], amounts[0], premiums[0], operationParams);
    } else if (operationParams.openPosition == 1) {
      return _executeClosePosition(assets[0], amounts[0], premiums[0], operationParams);
    } else if (operationParams.openPosition == 2) {
      return _executeAddToPosition(assets[0], amounts[0], premiums[0], operationParams);
    } else if (operationParams.openPosition == 3) {
      return _executeRemoveFromPosition(assets[0], amounts[0], premiums[0], operationParams);
    } else if (operationParams.openPosition == 4) {
      return _executeUpdateLeverage(assets[0], amounts[0], premiums[0], operationParams);
    } else {
      revert('Invalid operation type');
    }
  }

  function _executeOpenPosition(
    address asset,
    uint256 amount,
    uint256 premium,
    OperationParams memory params
  ) internal returns (bool) {
    require(asset == params.borrowToken, 'Invalid asset');
    require(amount > 0, 'Invalid borrow amount');

    // Approve and swap borrowed tokens
    IERC20(params.borrowToken).approve(address(swapController), amount);
    uint256 expectedAmountOut = swapController.getQuote(
      params.borrowToken,
      params.collateralToken,
      amount,
      DEFAULT_POOL_FEE
    );
    uint256 minAmountOut = _calculateMinAmountOut(expectedAmountOut);

    uint256 swappedAmount = swapController.swap(
      params.borrowToken,
      params.collateralToken,
      amount,
      minAmountOut,
      DEFAULT_POOL_FEE
    );

    // Deposit total collateral
    uint256 totalCollateral = params.initialCollateral + swappedAmount;
    IERC20(params.collateralToken).approve(address(lendingPool), totalCollateral);
    lendingPool.deposit(params.collateralToken, totalCollateral, params.user, REFERRAL_CODE);

    // Borrow to repay flash loan
    uint256 amountOwed = amount + premium;
    lendingPool.borrow(params.borrowToken, amountOwed, 2, REFERRAL_CODE, params.user);

    // Approve flash loan repayment
    IERC20(params.borrowToken).approve(address(params.flashLoanController), amountOwed);

    // Update user position
    positions[params.positionId] = UserPosition({
      user: params.user,
      collateralToken: params.collateralToken,
      borrowToken: params.borrowToken,
      initialCollateral: params.initialCollateral,
      totalCollateral: totalCollateral,
      totalBorrowed: amountOwed,
      leverageMultiplier: params.leverageMultiplier,
      isActive: true
    });

    userPositions[params.user].push(params.positionId);

    emit LeveragePositionOpened(
      params.positionId,
      params.user,
      params.collateralToken,
      params.borrowToken,
      params.initialCollateral,
      params.leverageMultiplier
    );

    return true;
  }

  function _executeClosePosition(
    address asset,
    uint256 amount,
    uint256 premium,
    OperationParams memory params
  ) internal returns (bool) {
    UserPosition storage position = positions[params.positionId];
    require(position.isActive, 'No active position');
    require(asset == position.borrowToken, 'Invalid asset');

    // Repay borrowed amount
    IERC20(position.borrowToken).approve(address(lendingPool), amount);
    lendingPool.repay(position.borrowToken, amount, 2, params.user);

    // Withdraw collateral
    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
      position.collateralToken
    );
    uint256 aTokenBalance = IERC20(reserveData.aTokenAddress).balanceOf(params.user);
    require(aTokenBalance >= position.totalCollateral, 'Insufficient aToken balance');

    IERC20(reserveData.aTokenAddress).transferFrom(
      params.user,
      address(this),
      position.totalCollateral
    );
    uint256 withdrawnAmount = lendingPool.withdraw(
      position.collateralToken,
      position.totalCollateral,
      address(this)
    );

    // Swap collateral to repay flash loan
    uint256 amountOwed = amount + premium;
    // uint256 expectedAmountIn = swapController.getQuote(
    //   position.borrowToken,
    //   position.collateralToken,
    //   amountOwed,
    //   DEFAULT_POOL_FEE
    // );
    // require(expectedAmountIn > 0, 'Invalid swap quote');
    // uint256 maxAmountIn = (expectedAmountIn * (10000 + DEFAULT_POOL_FEE + SLIPPAGE_TOLERANCE)) /
    //   10000;
    // require(withdrawnAmount > maxAmountIn, 'invalid position');

    IERC20(position.collateralToken).approve(address(swapController), withdrawnAmount);
    uint256 swappedAmount = swapController.swap(
      position.collateralToken,
      position.borrowToken,
      withdrawnAmount,
      amountOwed,
      DEFAULT_POOL_FEE
    );

    // Repay flash loan
    IERC20(position.borrowToken).approve(address(params.flashLoanController), amountOwed);

    // Return remaining collateral to user
    uint256 excessBorrowed = swappedAmount - amountOwed;
    if (excessBorrowed > 0) {
      IERC20(position.borrowToken).approve(address(swapController), excessBorrowed);
      uint256 swappedAmount = swapController.swap(
        position.borrowToken,
        position.collateralToken,
        excessBorrowed,
        0,
        DEFAULT_POOL_FEE
      );
      IERC20(position.collateralToken).transfer(params.user, swappedAmount);
    }

    emit LeveragePositionClosed(params.positionId, params.user, withdrawnAmount);
    delete positions[params.positionId];
    _removeUserPosition(params.user, params.positionId);

    return true;
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

  // Calculate Minimum Amount Out with Slippage
  function _calculateMinAmountOut(uint256 amountIn) internal view returns (uint256) {
    return (amountIn * (10000 - SLIPPAGE_TOLERANCE)) / 10000;
  }

  function _calculateMaxAmountOut(uint256 amountIn) internal view returns (uint256) {
    return (amountIn * (10000 + DEFAULT_POOL_FEE + SLIPPAGE_TOLERANCE)) / 10000;
  }

  // Calculate Max Borrow Amount Based on Current LTV, outputs value of borrow token
  function _calculateMaxBorrowAmount(
    address borrowToken,
    address collateralToken,
    uint256 totalCollateral,
    uint256 leverageMultiplier
  ) internal view returns (uint256) {
    // Get reserve configuration data to get the max LTV
    DataTypes.ReserveConfigurationMap memory config = lendingPool.getConfiguration(collateralToken);
    uint256 maxLTV = config.getLtv(); // This gets the maximum LTV for the asset (in basis points)

    // Get prices and decimals for both tokens
    uint256 collateralPrice = aaveOracle.getAssetPrice(collateralToken);
    uint256 borrowPrice = aaveOracle.getAssetPrice(borrowToken);
    uint256 collateralDecimals = IERC20Metadata(collateralToken).decimals();
    uint256 borrowDecimals = IERC20Metadata(borrowToken).decimals();

    // Convert collateral to USD value (8 decimals precision from Aave Oracle)
    uint256 collateralValueInUsd = (totalCollateral * collateralPrice) / 10 ** collateralDecimals;

    // Calculate max borrow based on LTV and leverage
    uint256 maxBorrowValueInUsd = (collateralValueInUsd * maxLTV * leverageMultiplier) / 10000; // ltv in basis points (100% = 10000)

    // Convert USD value back to borrow token amount, accounting for decimals
    return (maxBorrowValueInUsd * 10 ** borrowDecimals) / borrowPrice;
  }

  function _calculateRepayAmount(
    address borrowToken,
    uint256 borrowed
  ) internal view returns (uint256) {
    uint256 borrowPrice = aaveOracle.getAssetPrice(borrowToken);
    // Add small buffer for additional interest during flash loan (0.1%)
    return (borrowed * 1e8) / borrowPrice;
  }

  // Close Leverage Position
  function closeLeveragePosition(uint256 positionId) external nonReentrant {
    UserPosition storage position = positions[positionId];
    require(position.isActive, 'No active position');
    // Validate the user trying to close their own position
    require(position.user == msg.sender, 'Unauthorized to close position');

    // Check current health factor before closing
    (, , , , , uint256 healthFactor) = lendingPool.getUserAccountData(msg.sender);
    require(healthFactor > 1.05e18, 'Position health is too low');
    uint repayAmount = position.totalBorrowed; //_calculateRepayAmount(position.borrowToken, position.totalBorrowed);

    bytes memory params = abi.encode(
      OperationParams({
        positionId: positionId,
        user: msg.sender,
        collateralToken: position.collateralToken,
        borrowToken: position.borrowToken,
        initialCollateral: repayAmount,
        leverageMultiplier: 1,
        flashLoanController: address(flashLoanController),
        strategy: address(this),
        openPosition: 1
      })
    );

    flashLoanController.executeFlashLoan(position.borrowToken, repayAmount, params);
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

  // new

  function updateLeveragePosition(
    uint256 positionId,
    uint256 newInitialCollateral,
    uint256 newLeverageMultiplier
  ) external nonReentrant {
    UserPosition storage position = positions[positionId];
    require(position.isActive, 'No active position');
    require(position.user == msg.sender, 'Unauthorized to update position');
    require(newLeverageMultiplier > 1 && newLeverageMultiplier <= MAX_LEVERAGE, 'Invalid leverage');

    // Fetch current position data
    // uint256 currentCollateral = position.totalCollateral;
    // uint256 currentBorrowed = position.totalBorrowed;

    // Calculate the difference between new and current initial collateral
    int256 collateralDelta = int256(newInitialCollateral) - int256(position.initialCollateral);

    if (collateralDelta > 0) {
      // User is adding more collateral
      _addToPosition(positionId, position, uint256(collateralDelta));
    } else if (collateralDelta < 0) {
      // User is withdrawing collateral
      _repayPartOfPosition(positionId, position, uint256(-collateralDelta));
    }

    // Update the initial collateral value
    position.initialCollateral = newInitialCollateral;

    // Handle leverage update
    if (newLeverageMultiplier != position.leverageMultiplier) {
      _updateLeverage(positionId, position, newLeverageMultiplier);
    }

    // Check health factor after updating the position
    (, , , , , uint256 healthFactor) = lendingPool.getUserAccountData(msg.sender);
    require(healthFactor > 1.05e18, 'Position health is too low');
  }

  function _addToPosition(
    uint256 positionId,
    UserPosition storage position,
    uint256 additionalCollateral
  ) internal {
    // Transfer additional collateral from the user
    IERC20(position.collateralToken).transferFrom(msg.sender, address(this), additionalCollateral);

    // Use a flash loan to borrow the additional amount
    bytes memory params = abi.encode(
      OperationParams({
        positionId: positionId,
        user: msg.sender,
        collateralToken: position.collateralToken,
        borrowToken: position.borrowToken,
        initialCollateral: additionalCollateral,
        leverageMultiplier: position.leverageMultiplier,
        flashLoanController: address(flashLoanController),
        strategy: address(this),
        openPosition: 2 // Indicates this is an update, not a new position
      })
    );

    uint256 expectedAmountIn = swapController.getQuote(
      position.collateralToken,
      position.borrowToken,
      additionalCollateral * (position.leverageMultiplier - 1),
      DEFAULT_POOL_FEE // 0% buffer cause of flashloan
    );
    require(expectedAmountIn > 0, 'Invalid swap quote');

    flashLoanController.executeFlashLoan(position.borrowToken, expectedAmountIn, params);
  }

  function _repayPartOfPosition(
    uint256 positionId,
    UserPosition storage position,
    uint256 collateralToWithdraw
  ) internal {
    // Calculate the amount of borrowed tokens to repay based on the leverage multiplier
    // uint256 borrowToRepay = (collateralToWithdraw * (position.leverageMultiplier - 1));

    // Use a flash loan to repay the borrowed amount
    bytes memory params = abi.encode(
      OperationParams({
        positionId: positionId,
        user: msg.sender,
        collateralToken: position.collateralToken,
        borrowToken: position.borrowToken,
        initialCollateral: collateralToWithdraw,
        leverageMultiplier: position.leverageMultiplier,
        flashLoanController: address(flashLoanController),
        strategy: address(this),
        openPosition: 3 // Indicates this is an update, not a new position
      })
    );

    uint256 expectedAmountIn = swapController.getQuote(
      position.collateralToken,
      position.borrowToken,
      collateralToWithdraw * (position.leverageMultiplier - 1),
      DEFAULT_POOL_FEE // 0% buffer cause of flashloan
    );
    require(expectedAmountIn > 0, 'Invalid swap quote');

    flashLoanController.executeFlashLoan(position.borrowToken, expectedAmountIn, params);
  }

  function _updateLeverage(
    uint256 positionId,
    UserPosition storage position,
    uint256 newLeverageMultiplier
  ) internal {
    // Calculate the new borrowed amount based on the new leverage multiplier
    // uint256 newBorrowedAmount = (position.initialCollateral * (newLeverageMultiplier - 1));
    uint256 newBorrowedAmount = swapController.getQuote(
      position.collateralToken,
      position.borrowToken,
      position.initialCollateral * (newLeverageMultiplier - 1),
      0 // 0% buffer cause of flashloan
    );
    require(newBorrowedAmount > 0, 'Invalid swap quote');

    // Calculate the difference between new and current borrowed amount
    int256 borrowDelta = int256(newBorrowedAmount) - int256(position.totalBorrowed);

    if (borrowDelta > 0) {
      // User needs to borrow more
      uint256 additionalBorrow = uint256(borrowDelta);

      // Use a flash loan to facilitate the additional borrowing
      bytes memory params = abi.encode(
        OperationParams({
          positionId: positionId,
          user: position.user,
          collateralToken: position.collateralToken,
          borrowToken: position.borrowToken,
          initialCollateral: position.initialCollateral,
          leverageMultiplier: newLeverageMultiplier,
          flashLoanController: address(flashLoanController),
          strategy: address(this),
          openPosition: 4 // Indicates this is a leverage update
        })
      );

      flashLoanController.executeFlashLoan(position.borrowToken, additionalBorrow, params);
      // position.totalBorrowed += additionalBorrow;
    } else if (borrowDelta < 0) {
      // User needs to repay part of the borrowed amount
      uint256 repayAmount = uint256(-borrowDelta);
      require(repayAmount <= position.totalBorrowed, 'Cannot repay more than current borrowed');

      // Use a flash loan to repay the excess borrowed amount
      bytes memory params = abi.encode(
        OperationParams({
          positionId: positionId,
          user: position.user,
          collateralToken: position.collateralToken,
          borrowToken: position.borrowToken,
          initialCollateral: position.initialCollateral,
          leverageMultiplier: newLeverageMultiplier,
          flashLoanController: address(flashLoanController),
          strategy: address(this),
          openPosition: 4 // Indicates this is a leverage update
        })
      );

      flashLoanController.executeFlashLoan(position.borrowToken, repayAmount, params);
      // position.totalBorrowed -= repayAmount;
    }

    // Update the leverage multiplier
    position.leverageMultiplier = newLeverageMultiplier;
  }

  function _executeAddToPosition(
    address asset,
    uint256 amount,
    uint256 premium,
    OperationParams memory params
  ) internal returns (bool) {
    UserPosition storage position = positions[params.positionId];
    require(position.isActive, 'No active position');

    // Swap borrowed tokens to collateral tokens
    IERC20(params.borrowToken).approve(address(swapController), amount);
    uint256 expectedAmountOut = swapController.getQuote(
      params.borrowToken,
      params.collateralToken,
      amount,
      DEFAULT_POOL_FEE
    );
    uint256 minAmountOut = _calculateMinAmountOut(expectedAmountOut);

    uint256 swappedAmount = swapController.swap(
      params.borrowToken,
      params.collateralToken,
      amount,
      minAmountOut,
      DEFAULT_POOL_FEE
    );

    // Deposit the swapped collateral into the lending pool
    uint256 totalCollateral = params.initialCollateral + swappedAmount;
    IERC20(params.collateralToken).approve(address(lendingPool), totalCollateral);
    lendingPool.deposit(params.collateralToken, totalCollateral, params.user, REFERRAL_CODE);

    // Borrow to repay the flash loan
    uint256 amountOwed = amount + premium;
    lendingPool.borrow(params.borrowToken, amountOwed, 2, REFERRAL_CODE, params.user);

    // Approve flash loan repayment
    IERC20(params.borrowToken).approve(address(params.flashLoanController), amountOwed);

    // Update the position's total collateral and borrowed amount
    position.totalCollateral += totalCollateral;
    position.totalBorrowed += amountOwed;

    emit LeveragePositionAdded(
      params.positionId,
      params.user,
      params.collateralToken,
      params.borrowToken,
      totalCollateral, // addedCollateral
      position.totalCollateral, // newTotalCollateral
      position.totalBorrowed // newTotalBorrowed
    );

    return true;
  }

  function _executeRemoveFromPosition(
    address asset,
    uint256 amount,
    uint256 premium,
    OperationParams memory params
  ) internal returns (bool) {
    UserPosition storage position = positions[params.positionId];
    require(position.isActive, 'No active position');
    require(asset == position.borrowToken, 'Invalid asset');

    // Swap collateral to repay flash loan
    uint collateralToWithdraw = params.initialCollateral * params.leverageMultiplier;

    // Repay borrowed amount
    IERC20(position.borrowToken).approve(address(lendingPool), amount);
    lendingPool.repay(position.borrowToken, amount, 2, params.user);

    // Withdraw collateral
    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
      position.collateralToken
    );
    require(
      IERC20(reserveData.aTokenAddress).balanceOf(params.user) >= position.totalCollateral,
      'Insufficient aToken balance'
    );

    IERC20(reserveData.aTokenAddress).transferFrom(
      params.user,
      address(this),
      collateralToWithdraw
    );
    uint256 withdrawnAmount = lendingPool.withdraw(
      position.collateralToken,
      collateralToWithdraw,
      address(this)
    );

    uint256 amountOwed = amount + premium;

    IERC20(position.collateralToken).approve(address(swapController), withdrawnAmount);
    uint256 swappedAmount = swapController.swap(
      position.collateralToken,
      position.borrowToken,
      withdrawnAmount,
      amountOwed,
      DEFAULT_POOL_FEE
    );

    // Repay flash loan
    IERC20(position.borrowToken).approve(address(params.flashLoanController), amountOwed);

    // Return remaining collateral to user
    uint256 excessBorrowed = swappedAmount - amountOwed;
    if (excessBorrowed > 0) {
      IERC20(position.borrowToken).approve(address(swapController), excessBorrowed);
      uint256 swappedAmount = swapController.swap(
        position.borrowToken,
        position.collateralToken,
        excessBorrowed,
        0,
        DEFAULT_POOL_FEE
      );
      IERC20(position.collateralToken).transfer(params.user, swappedAmount);
    }

    // Update the position's total collateral and borrowed amount
    position.totalCollateral -= collateralToWithdraw;
    position.totalBorrowed -= amountOwed;

    emit LeveragePositionRemoved(
      params.positionId,
      params.user,
      params.collateralToken,
      params.borrowToken,
      collateralToWithdraw, // removedCollateral
      position.totalCollateral, // newTotalCollateral
      position.totalBorrowed // newTotalBorrowed
    );

    return true;
  }

  function _executeUpdateLeverage(
    address asset,
    uint256 amount,
    uint256 premium,
    OperationParams memory params
  ) internal returns (bool) {
    UserPosition storage position = positions[params.positionId];
    require(position.isActive, 'No active position');

    if (params.leverageMultiplier > position.leverageMultiplier) {
      // Increasing leverage: borrow more and swap into collateral
      IERC20(params.borrowToken).approve(address(swapController), amount);
      uint256 expectedAmountOut = swapController.getQuote(
        params.borrowToken,
        params.collateralToken,
        amount,
        DEFAULT_POOL_FEE
      );
      uint256 minAmountOut = _calculateMinAmountOut(expectedAmountOut);

      uint256 swappedAmount = swapController.swap(
        params.borrowToken,
        params.collateralToken,
        amount,
        minAmountOut,
        DEFAULT_POOL_FEE
      );

      // Deposit the swapped collateral into the lending pool
      IERC20(params.collateralToken).approve(address(lendingPool), swappedAmount);
      lendingPool.deposit(params.collateralToken, swappedAmount, params.user, REFERRAL_CODE);

      // Borrow to repay the flash loan
      uint256 amountOwed = amount + premium;
      lendingPool.borrow(params.borrowToken, amountOwed, 2, REFERRAL_CODE, params.user);

      // Approve flash loan repayment
      IERC20(params.borrowToken).approve(address(params.flashLoanController), amountOwed);

      // Update the position's total collateral and borrowed amount
      position.totalCollateral += swappedAmount;
      position.totalBorrowed += amountOwed;
    } else {
      // Decreasing leverage: repay part of the borrowed amount
      IERC20(params.borrowToken).approve(address(lendingPool), amount);
      lendingPool.repay(params.borrowToken, amount, 2, params.user);

      DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
        position.collateralToken
      );
      require(
        IERC20(reserveData.aTokenAddress).balanceOf(params.user) >= position.totalCollateral,
        'Insufficient aToken balance'
      );

      // Withdraw collateral and swap part of it to repay the flash loan
      uint256 collateralToWithdraw = params.initialCollateral *
        (position.leverageMultiplier - params.leverageMultiplier);
      IERC20(reserveData.aTokenAddress).transferFrom(
        params.user,
        address(this),
        collateralToWithdraw
      );

      uint256 withdrawnAmount = lendingPool.withdraw(
        params.collateralToken,
        collateralToWithdraw,
        address(this)
      );

      // Swap part of the collateral to repay the flash loan
      uint256 amountOwed = amount + premium;
      IERC20(position.collateralToken).approve(address(swapController), withdrawnAmount);

      uint256 swappedAmount = swapController.swap(
        position.collateralToken,
        position.borrowToken,
        withdrawnAmount,
        amountOwed,
        DEFAULT_POOL_FEE
      );

      // Repay flash loan
      IERC20(position.borrowToken).approve(address(params.flashLoanController), amountOwed);

      // Return remaining collateral to user
      uint256 excessBorrowed = swappedAmount - amountOwed;
      if (excessBorrowed > 0) {
        IERC20(position.borrowToken).approve(address(swapController), excessBorrowed);
        uint256 swappedAmount = swapController.swap(
          position.borrowToken,
          position.collateralToken,
          excessBorrowed,
          0,
          DEFAULT_POOL_FEE
        );
        IERC20(position.collateralToken).transfer(params.user, swappedAmount);
      }

      // Update the position's total collateral and borrowed amount
      position.totalCollateral -= collateralToWithdraw;
      position.totalBorrowed -= amount;
    }

    // Update the leverage multiplier
    position.leverageMultiplier = params.leverageMultiplier;

    emit LeveragePositionLeverageUpdated(
      params.positionId,
      params.user,
      params.collateralToken,
      params.borrowToken,
      position.leverageMultiplier, // oldLeverageMultiplier
      params.leverageMultiplier, // newLeverageMultiplier
      position.totalCollateral, // newTotalCollateral
      position.totalBorrowed // newTotalBorrowed
    );

    return true;
  }

  // Admin Functions
  function addAllowedCollateralToken(address token) external onlyOwner {
    allowedCollateralTokens[token] = true;
  }

  function addAllowedBorrowToken(address token) external onlyOwner {
    allowedBorrowTokens[token] = true;
  }

  function removeAllowedCollateralToken(address token) external onlyOwner {
    allowedCollateralTokens[token] = false;
  }

  function removeAllowedBorrowToken(address token) external onlyOwner {
    allowedBorrowTokens[token] = false;
  }

  function updateSwapFee(uint24 _swapFee) external onlyOwner {
    DEFAULT_POOL_FEE = _swapFee;
  }

  function updateSwapController(address _newSwapController) external onlyOwner {
    require(_newSwapController != address(0), 'Invalid address');
    swapController = ISwapController(_newSwapController);
  }
  function updateFlashLoanController(address _newFlashLoanController) external onlyOwner {
    require(_newFlashLoanController != address(0), 'Invalid address');
    flashLoanController = IFlashLoanController(_newFlashLoanController);
  }
}
