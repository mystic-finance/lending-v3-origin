// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
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
  ) external view returns (uint256 expectedAmountOut);
}

interface IFlashLoanController {
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external;
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
    bool openPosition;
  }

  // Constants
  uint256 public constant MAX_LEVERAGE = 20;
  uint256 public constant SLIPPAGE_TOLERANCE = 50; // 0.5%
  uint16 public constant REFERRAL_CODE = 0;
  uint24 public DEFAULT_POOL_FEE = 500; // 5% pool fee
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

  constructor(
    address _lendingPool,
    address _swapController,
    address _flashLoanController
  ) Ownable(msg.sender) {
    lendingPool = IPool(_lendingPool);
    swapController = ISwapController(_swapController);
    flashLoanController = IFlashLoanController(_flashLoanController);
    aaveOracle = IAaveOracle((lendingPool.ADDRESSES_PROVIDER()).getPriceOracle());
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
        openPosition: true
      })
    );

    // Initiate flash loan
    uint256 expectedAmountIn = swapController.getQuote(
      collateralToken,
      borrowToken,
      initialCollateral * (leverageMultiplier - 1),
      0 // 0% buffer cause of flashloan
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

    OperationParams memory operationParams = abi.decode(params, (OperationParams));

    if (operationParams.openPosition) {
      return _executeOpenPosition(assets[0], amounts[0], premiums[0], operationParams);
    } else {
      return _executeClosePosition(assets[0], amounts[0], premiums[0], operationParams);
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
    uint256 expectedAmountIn = swapController.getQuote(
      position.borrowToken,
      position.collateralToken,
      amountOwed,
      DEFAULT_POOL_FEE
    );
    require(expectedAmountIn > 0, 'Invalid swap quote');
    uint256 maxAmountIn = (expectedAmountIn * (10000)) / (10000 - DEFAULT_POOL_FEE);
    require(withdrawnAmount > maxAmountIn, 'invalid position');

    IERC20(position.collateralToken).approve(address(swapController), maxAmountIn);
    uint256 swappedAmount = swapController.swap(
      position.collateralToken,
      position.borrowToken,
      maxAmountIn,
      amountOwed,
      DEFAULT_POOL_FEE
    );

    // Repay flash loan
    IERC20(position.borrowToken).approve(address(params.flashLoanController), amountOwed);

    // Return remaining collateral to user
    uint256 remainingCollateral = withdrawnAmount - maxAmountIn;
    if (remainingCollateral > 0) {
      IERC20(position.collateralToken).transfer(params.user, remainingCollateral);
    }

    // Return excess borrowed tokens if any
    uint256 excessBorrowed = swappedAmount - amountOwed;
    if (excessBorrowed > 0) {
      IERC20(position.borrowToken).transfer(params.user, excessBorrowed);
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
    require(healthFactor > 1, 'Position health is too low');
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
        openPosition: false
      })
    );

    flashLoanController.executeFlashLoan(position.borrowToken, repayAmount, params);
  }

  function getUserPositions(address user) external view returns (uint256[] memory) {
    return userPositions[user];
  }

  // function getUserActivePositions(address user) external view returns (UserPosition[] memory) {
  //   uint256[] memory positionIds = userPositions[user];
  //   uint256 activeCount = 0;

  //   // Count active positions
  //   for (uint256 i = 0; i < positionIds.length; i++) {
  //     if (positions[positionIds[i]].isActive) {
  //       activeCount++;
  //     }
  //   }

  //   // Create array of active positions
  //   UserPosition[] memory activePositions = new UserPosition[](activeCount);
  //   uint256 currentIndex = 0;

  //   for (uint256 i = 0; i < positionIds.length; i++) {
  //     if (positions[positionIds[i]].isActive) {
  //       activePositions[currentIndex] = positions[positionIds[i]];
  //       currentIndex++;
  //     }
  //   }

  //   return activePositions;
  // }

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

  // Fallback
  // receive() external payable {}
}
