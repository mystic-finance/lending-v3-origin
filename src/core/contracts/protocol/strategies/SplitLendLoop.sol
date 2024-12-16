// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface ILendingPool {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;
  function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
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

interface IFlashLoanController {
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external;
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

contract SplitLendingVault is ERC20, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Structs
  struct SplitPosition {
    uint256 lendingAmount;
    uint256 leverageAmount;
    uint256 borrowedAmount;
    address collateralToken;
    address borrowToken;
    bool isActive;
  }

  // Core Tokens and Protocols
  IERC20 public immutable underlyingToken;
  ILendingPool public immutable lendingPool;
  IFlashLoanController public immutable flashLoanController;
  ISwapController public immutable swapController;

  // Configuration Constants
  uint256 public constant MAX_SPLIT_RATIO = 8000; // 80% max can be used for leverage
  uint256 public constant MIN_SPLIT_RATIO = 2000; // 20% min for lending
  uint256 public constant LEVERAGE_MULTIPLIER = 5; // 3x leverage
  uint256 public constant SLIPPAGE_TOLERANCE = 50; // 0.5%
  uint24 public constant POOL_FEE = 3000; // 0.3% pool fee

  // User Positions
  mapping(address => SplitPosition) public userPositions;

  // Events
  event PositionSplit(address indexed user, uint256 lendingAmount, uint256 leverageAmount);
  event PositionClosed(address indexed user, uint256 totalReturned);
  event FlashLoanExecuted(address indexed asset, uint256 amount);

  constructor(
    address _underlyingToken,
    address _lendingPool,
    address _flashLoanController,
    address _swapController
  ) ERC20('Split Lending Share', 'SLS') Ownable(msg.sender) {
    underlyingToken = IERC20(_underlyingToken);
    lendingPool = ILendingPool(_lendingPool);
    flashLoanController = IFlashLoanController(_flashLoanController);
    swapController = ISwapController(_swapController);
  }

  // Main Split Position Function
  function createSplitPosition(
    uint256 amount,
    uint256 splitRatio,
    address collateralToken,
    address borrowToken
  ) external nonReentrant {
    // Validate split ratio
    require(splitRatio >= MIN_SPLIT_RATIO && splitRatio <= MAX_SPLIT_RATIO, 'Invalid split ratio');

    // Transfer tokens from user
    underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

    // Calculate split amounts
    uint256 lendingAmount = (amount * (10000 - splitRatio)) / 10000;
    uint256 leverageAmount = (amount * splitRatio) / 10000;

    // Deposit lending portion to lending pool
    underlyingToken.approve(address(lendingPool), lendingAmount);
    lendingPool.deposit(address(underlyingToken), lendingAmount, address(this), 0);

    // Prepare params for flash loan
    uint256 borrowAmount = _calculateMaxBorrowAmount(collateralToken, leverageAmount);
    bytes memory params = abi.encode(msg.sender, collateralToken, borrowToken, leverageAmount);

    // Initiate flash loan
    flashLoanController.executeFlashLoan(borrowToken, borrowAmount, params);

    // Store user position
    userPositions[msg.sender] = SplitPosition({
      lendingAmount: lendingAmount,
      leverageAmount: leverageAmount,
      borrowedAmount: borrowAmount,
      collateralToken: collateralToken,
      borrowToken: borrowToken,
      isActive: true
    });

    // Mint vault shares
    _mint(msg.sender, amount);

    emit PositionSplit(msg.sender, lendingAmount, leverageAmount);
  }

  // Flash Loan Callback
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external {
    require(msg.sender == address(flashLoanController), 'Unauthorized');

    emit FlashLoanExecuted(asset, amount);

    // Decode params
    (address user, address collateralToken, address borrowToken, uint256 leverageAmount) = abi
      .decode(params, (address, address, address, uint256));

    // Swap borrowed tokens to collateral
    uint256 swappedAmount = _performSwap(
      borrowToken,
      collateralToken,
      amount,
      _calculateMinAmountOut(amount)
    );

    // Deposit collateral to lending pool
    IERC20(collateralToken).approve(address(lendingPool), swappedAmount);
    lendingPool.deposit(collateralToken, swappedAmount, address(this), 0);

    // Borrow additional amount
    uint256 borrowAmount = _calculateMaxBorrowAmount(collateralToken, swappedAmount);
    lendingPool.borrow(borrowToken, borrowAmount, 2, 0, address(this));

    // Repay flash loan
    IERC20(borrowToken).approve(address(flashLoanController), amount);
  }

  // Close Split Position
  function closeSplitPosition() external nonReentrant {
    SplitPosition storage position = userPositions[msg.sender];
    require(position.isActive, 'No active position');

    // Repay borrowed amount
    IERC20(position.borrowToken).approve(address(lendingPool), position.borrowedAmount);
    lendingPool.repay(position.borrowToken, position.borrowedAmount, 2, address(this));

    // Withdraw lending portion
    uint256 lendingReturns = lendingPool.withdraw(
      address(underlyingToken),
      position.lendingAmount,
      address(this)
    );

    // Withdraw collateral
    uint256 collateralReturns = lendingPool.withdraw(
      position.collateralToken,
      type(uint256).max,
      address(this)
    );

    // Calculate total returns
    uint256 totalReturns = lendingReturns + collateralReturns;

    // Transfer returns to user
    underlyingToken.safeTransfer(msg.sender, totalReturns);

    // Burn vault shares
    _burn(msg.sender, totalSupply());

    // Reset position
    delete userPositions[msg.sender];

    emit PositionClosed(msg.sender, totalReturns);
  }

  // Internal Swap Function
  function _performSwap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut
  ) internal returns (uint256) {
    IERC20(tokenIn).approve(address(swapController), amountIn);

    return swapController.swap(tokenIn, tokenOut, amountIn, minAmountOut, POOL_FEE);
  }

  // Calculate Minimum Amount Out with Slippage
  function _calculateMinAmountOut(uint256 amountIn) internal view returns (uint256) {
    return (amountIn * (10000 - SLIPPAGE_TOLERANCE)) / 10000;
  }

  // Calculate Max Borrow Amount
  function _calculateMaxBorrowAmount(
    address collateralToken,
    uint256 totalCollateral
  ) internal view returns (uint256) {
    // Get current LTV from lending pool
    (, , , , uint256 ltv, ) = lendingPool.getUserAccountData(address(this));

    // Calculate max borrow based on LTV and leverage multiplier
    uint256 maxBorrowPercentage = (ltv * LEVERAGE_MULTIPLIER) / 100;
    return (totalCollateral * maxBorrowPercentage) / 100;
  }

  // Utility Functions
  function getPositionDetails(address user) external view returns (SplitPosition memory) {
    return userPositions[user];
  }

  // Fallback
  receive() external payable {}
}
