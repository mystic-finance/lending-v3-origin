// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import {IPool} from '../../interfaces/IPool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

// Interfaces for Controllers
interface ISwapController {
  function swap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOutMinimum,
    uint24 poolFee
  ) external returns (uint256 amountOut);
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
    address user;
    address collateralToken;
    address borrowToken;
    uint256 initialCollateral;
    uint256 leverageMultiplier;
    address flashLoanController;
    address strategy;
  }

  // Constants
  uint256 public constant MAX_LEVERAGE = 20;
  uint256 public constant SLIPPAGE_TOLERANCE = 50; // 0.5%
  uint16 public constant REFERRAL_CODE = 0;
  uint24 public constant DEFAULT_POOL_FEE = 3000; // 0.3% pool fee

  // External Contracts
  IPool public lendingPool;
  ISwapController public swapController;
  IFlashLoanController public flashLoanController;

  // Mappings
  mapping(address => UserPosition) public userPositions;
  mapping(address => bool) public allowedCollateralTokens;
  mapping(address => bool) public allowedBorrowTokens;

  // Events
  event LeveragePositionOpened(
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 initialAmount,
    uint256 leverageMultiplier
  );
  event LeveragePositionClosed(address indexed user, uint256 collateralReturned);

  constructor(
    address _lendingPool,
    address _swapController,
    address _flashLoanController
  ) Ownable(msg.sender) {
    lendingPool = IPool(_lendingPool);
    swapController = ISwapController(_swapController);
    flashLoanController = IFlashLoanController(_flashLoanController);
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

    // Encode additional params for flash loan operation
    bytes memory params = abi.encode(
      msg.sender,
      collateralToken,
      borrowToken,
      initialCollateral,
      leverageMultiplier,
      flashLoanController,
      address(this)
    );

    // Initiate flash loan
    uint256 borrowAmount = _calculateMaxBorrowAmount(
      collateralToken,
      initialCollateral,
      leverageMultiplier
    );

    flashLoanController.executeFlashLoan(borrowToken, borrowAmount, params);
  }

  // Flash Loan Callback
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    // Verify caller is the flash loan controller
    require(msg.sender == address(flashLoanController), 'Unauthorized flash loan');

    // Decode and validate params
    OperationParams memory operationParams = abi.decode(params, (OperationParams));

    // Additional validation
    require(assets[0] == operationParams.borrowToken, 'Invalid flash loan asset');
    require(amounts[0] > 0, 'Invalid borrow amount');
    IERC20(operationParams.borrowToken).approve(address(swapController), amounts[0]);

    // Swap borrowed tokens to collateral
    uint256 minAmountOut = _calculateMinAmountOut(amounts[0]);
    uint256 swappedAmount = swapController.swap(
      operationParams.borrowToken,
      operationParams.collateralToken,
      amounts[0],
      minAmountOut,
      DEFAULT_POOL_FEE
    );

    IERC20(operationParams.collateralToken).transferFrom(
      address(swapController),
      address(this),
      swappedAmount
    );

    // Deposit total collateral to lending pool
    uint256 totalCollateral = operationParams.initialCollateral + swappedAmount;
    IERC20(operationParams.collateralToken).approve(address(lendingPool), totalCollateral);
    lendingPool.deposit(
      operationParams.collateralToken,
      totalCollateral,
      address(this),
      REFERRAL_CODE
    );

    // Calculate and borrow up to LTV
    uint256 borrowAmount = _calculateMaxBorrowAmount(
      operationParams.collateralToken,
      totalCollateral,
      operationParams.leverageMultiplier
    );
    lendingPool.borrow(operationParams.borrowToken, borrowAmount, 2, REFERRAL_CODE, address(this));

    // Prepare to repay flash loan
    uint256 amountOwed = amounts[0] + premiums[0];
    IERC20(operationParams.borrowToken).approve(
      address(operationParams.flashLoanController),
      amountOwed
    );

    // Store user position
    userPositions[operationParams.user] = UserPosition({
      user: operationParams.user,
      collateralToken: operationParams.collateralToken,
      borrowToken: operationParams.borrowToken,
      initialCollateral: operationParams.initialCollateral,
      totalCollateral: totalCollateral,
      totalBorrowed: borrowAmount,
      leverageMultiplier: operationParams.leverageMultiplier,
      isActive: true
    });

    emit LeveragePositionOpened(
      operationParams.user,
      operationParams.collateralToken,
      operationParams.borrowToken,
      operationParams.initialCollateral,
      operationParams.leverageMultiplier
    );

    return true;
  }

  // Calculate Minimum Amount Out with Slippage
  function _calculateMinAmountOut(uint256 amountIn) internal view returns (uint256) {
    return (amountIn * (10000 - SLIPPAGE_TOLERANCE)) / 10000;
  }

  // Calculate Max Borrow Amount Based on Current LTV
  function _calculateMaxBorrowAmount(
    address collateralToken,
    uint256 totalCollateral,
    uint256 leverageMultiplier
  ) internal view returns (uint256) {
    // Get current LTV from lending pool
    (, , , , uint256 ltv, ) = lendingPool.getUserAccountData(address(this));

    // Calculate max borrow based on LTV and leverage
    uint256 maxBorrowPercentage = (ltv * leverageMultiplier) / 100;
    return (totalCollateral * maxBorrowPercentage) / 100;
  }

  // Close Leverage Position
  function closeLeveragePosition() external nonReentrant {
    UserPosition storage position = userPositions[msg.sender];
    require(position.isActive, 'No active position');

    // Validate the user trying to close their own position
    require(position.user == msg.sender, 'Unauthorized to close position');

    // Check current health factor before closing
    (, , , , , uint256 healthFactor) = lendingPool.getUserAccountData(address(this));
    require(healthFactor > 1, 'Position health is too low');

    // Repay borrowed amount
    uint256 repayAmount = Math.min(
      position.totalBorrowed,
      IERC20(position.borrowToken).balanceOf(address(this))
    );

    IERC20(position.borrowToken).approve(address(lendingPool), repayAmount);
    lendingPool.repay(position.borrowToken, repayAmount, 2, address(this));

    // Withdraw collateral
    uint256 withdrawAmount = Math.min(
      position.totalCollateral,
      IERC20(position.collateralToken).balanceOf(address(this))
    );
    lendingPool.withdraw(position.collateralToken, withdrawAmount, msg.sender);

    emit LeveragePositionClosed(msg.sender, withdrawAmount);

    // Reset position
    delete userPositions[msg.sender];
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

  // Fallback
  receive() external payable {}
}
