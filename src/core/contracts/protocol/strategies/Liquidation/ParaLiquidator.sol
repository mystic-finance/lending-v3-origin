// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
import 'src/core/contracts/interfaces/IPriceOracleGetter.sol';
import 'src/core/contracts/interfaces/IAToken.sol';
import 'src/core/contracts/interfaces/IPool.sol';
import 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {FlashLoanController} from '../FlashLoanController.sol';
import 'src/core/contracts/protocol/libraries/math/PercentageMath.sol';

/// @title CompoundMath
/// @dev Library emulating in solidity 8+ the behavior of Compound's mulScalarTruncate and divScalarByExpTruncate functions.
library CompoundMath {
  error NumberExceeds224Bits();
  error NumberExceeds32Bits();

  function mul(uint256 x, uint256 y) internal pure returns (uint256) {
    return (x * y) / 1e18;
  }

  function div(uint256 x, uint256 y) internal pure returns (uint256) {
    return ((1e18 * x * 1e18) / y) / 1e18;
  }

  function safe224(uint256 n) internal pure returns (uint224) {
    if (n >= 2 ** 224) revert NumberExceeds224Bits();
    return uint224(n);
  }

  function safe32(uint256 n) internal pure returns (uint32) {
    if (n >= 2 ** 32) revert NumberExceeds32Bits();
    return uint32(n);
  }

  function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
    return a < b ? (a < c ? a : c) : (b < c ? b : c);
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a - b : 0;
  }
}

interface IERC3156FlashBorrower {
  function executeOperation(
    address[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    address initiator,
    bytes calldata data
  ) external returns (bool);
}

interface IERC3156FlashLender {
  function maxFlashLoan(address token) external view returns (uint256);
  function flashFee(address token, uint256 amount) external view returns (uint256);
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address[] memory tokens,
    uint256[] memory amounts,
    bytes calldata data
  ) external returns (bool);
}

/// @dev A minimal ERC20 safe transfer library.
library SafeTransferLib {
  function safeTransferETH(address to, uint256 amount) internal {
    bool success;
    assembly {
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }
    require(success, 'ETH_TRANSFER_FAILED');
  }

  function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) internal {
    bool success;
    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemPtr, 4), from)
      mstore(add(freeMemPtr, 36), to)
      mstore(add(freeMemPtr, 68), amount)
      success := and(
        or(
          and(eq(mload(0), 1), gt(returndatasize(), 31)),
          iszero(returndatasize())
        ),
        call(gas(), token, 0, freeMemPtr, 100, 0, 32)
      )
    }
    require(success, 'TRANSFER_FROM_FAILED');
  }

  function safeTransfer(ERC20 token, address to, uint256 amount) internal {
    bool success;
    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemPtr, 4), to)
      mstore(add(freeMemPtr, 36), amount)
      success := and(
        or(
          and(eq(mload(0), 1), gt(returndatasize(), 31)),
          iszero(returndatasize())
        ),
        call(gas(), token, 0, freeMemPtr, 68, 0, 32)
      )
    }
    require(success, 'TRANSFER_FAILED');
  }

  function safeApprove(ERC20 token, address to, uint256 amount) internal {
    bool success;
    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemPtr, 4), to)
      mstore(add(freeMemPtr, 36), amount)
      success := and(
        or(
          and(eq(mload(0), 1), gt(returndatasize(), 31)),
          iszero(returndatasize())
        ),
        call(gas(), token, 0, freeMemPtr, 68, 0, 32)
      )
    }
    require(success, 'APPROVE_FAILED');
  }
}

interface IWETH {
  function deposit() external payable;
  function withdraw(uint256) external;
}

/// @notice Minimal interface for Paraswap’s swap functionality.
/// (Adjust these functions to match the actual Paraswap aggregator interface.)
interface IParaSwap {
  function swap(
    address fromToken,
    address toToken,
    uint256 amount,
    uint256 minReturn,
    bytes calldata swapData
  ) external payable returns (uint256);
  
  /// @notice Returns a quote for a swap (this is just an example signature).
  function getExpectedReturn(
    address fromToken,
    address toToken,
    uint256 amount,
    bytes calldata swapData
  ) external view returns (uint256);
}

/// @notice Dummy interface for Paraswap’s liquidation “view” function.  
/// (In practice you may need to integrate with off-chain data or a Paraswap subgraph.)
interface IParaSwapLiquidator {
  function getLiquidatableUsers() external view returns (address[] memory users, uint256[] memory repayAmounts);
}

/// @notice Minimal interface for a Balancer-style flashloan provider.
interface IBalancerFlashLoan {
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address[] memory tokens,
    uint256[] memory amounts,
    bytes memory userData
  ) external;
}

/// @title FlashMintLiquidator
/// @dev Modified liquidation bot that uses Paraswap for swapping (and optionally for checking liquidatable users)
///      and supports choosing either an Aave- or Balancer-style flashloan.
contract FlashMintLiquidator is ReentrancyGuard, Ownable, IERC3156FlashBorrower {
  using SafeTransferLib for ERC20;
  using CompoundMath for uint256;
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  uint256 public constant BASIS_POINTS = 10_000;
  bytes32 public constant FLASHLOAN_CALLBACK = keccak256('ERC3156FlashBorrower.onFlashLoan');

  IPoolAddressesProvider public immutable addressesProvider;
  IPool public immutable aavePool; // assumed to be Aave's lending pool (flashloan provider)
  uint256 public slippageTolerance;

  /// @notice Choice of flashloan provider.
  enum FlashLoanProvider { Aave, Balancer }
  FlashLoanProvider public flashLoanProvider;

  /// @notice In case you want to use Balancer flashloans.
  IBalancerFlashLoan public balancerFlashLoan;

  /// @notice Paraswap swap aggregator.
  IParaSwap public paraswap;
  /// @notice Optionally, a Paraswap-based liquidation checker.
  IParaSwapLiquidator public paraswapLiquidator;

  event Liquidated(
    address indexed liquidator,
    address borrower,
    address indexed poolTokenBorrowedAddress,
    address indexed poolTokenCollateralAddress,
    uint256 amount,
    uint256 seized,
    bool usingFlashLoan
  );
  event FlashLoanTaken(address indexed initiator, uint256 amount);
  event Swapped(
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );
  event SlippageToleranceSet(uint256 newTolerance);
  event FlashLoanProviderSet(FlashLoanProvider provider);

  error OnlyLiquidator();
  error UnknownLender();
  error UnknownInitiator();
  error NoProfitableLiquidation();
  error ValueAboveBasisPoints();

  struct FlashLoanParams {
    address collateralUnderlying;
    address borrowedUnderlying;
    address poolTokenCollateral;
    address poolTokenBorrowed;
    address liquidator;
    address borrower;
    uint256 toLiquidate;
    bytes swapData; // data for Paraswap swap call
  }

  struct LiquidateParams {
    ERC20 collateralUnderlying;
    ERC20 borrowedUnderlying;
    IAToken poolTokenCollateral;
    IAToken poolTokenBorrowed;
    address liquidator;
    address borrower;
    uint256 toRepay;
  }

  constructor(
    IParaSwap _paraswap,
    IPoolAddressesProvider _addressesProvider,
    uint256 _slippageTolerance,
    FlashLoanProvider _flashLoanProvider
  ) Ownable(msg.sender) {
    paraswap = _paraswap;
    addressesProvider = _addressesProvider;
    aavePool = IPool(_addressesProvider.getPool());
    slippageTolerance = _slippageTolerance;
    flashLoanProvider = _flashLoanProvider;
  }

  /// @notice Set slippage tolerance (in basis points)
  function setSlippageTolerance(uint256 _newTolerance) external onlyOwner {
    require(_newTolerance <= BASIS_POINTS, "Value above basis points");
    slippageTolerance = _newTolerance;
    emit SlippageToleranceSet(_newTolerance);
  }

  /// @notice Set the flashloan provider. In Aave mode the aavePool is used,
  /// in Balancer mode, you must set the balancer flashloan address.
  function setFlashLoanProvider(FlashLoanProvider _provider, address _balancerFlashLoanAddress) external onlyOwner {
    flashLoanProvider = _provider;
    if (_provider == FlashLoanProvider.Balancer) {
      balancerFlashLoan = IBalancerFlashLoan(_balancerFlashLoanAddress);
    }
    emit FlashLoanProviderSet(_provider);
  }

  /// @notice Set an external ParaswapLiquidator (if available) to query liquidatable users.
  function setParaSwapLiquidator(address _liquidator) external onlyOwner {
    paraswapLiquidator = IParaSwapLiquidator(_liquidator);
  }

  /// @notice Example function that returns liquidatable users according to Paraswap.
  /// In practice this may be more complex and/or off-chain.
  function getLiquidatableUsers() external view returns (address[] memory users, uint256[] memory repayAmounts) {
    require(address(paraswapLiquidator) != address(0), "No ParaSwap liquidator set");
    return paraswapLiquidator.getLiquidatableUsers();
  }

  modifier onlyLiquidator() {
    require(msg.sender == owner(), "Only liquidator can call this function");
    _;
  }

  /// @notice Entry point for a liquidation call.
  /// If the caller already holds the needed funds then the liquidation is executed directly.
  /// Otherwise a flashloan is taken.
  function liquidate(
    address _poolTokenBorrowedAddress,
    address _poolTokenCollateralAddress,
    address _borrower,
    uint256 _repayAmount,
    bytes memory _swapData
  ) external nonReentrant onlyLiquidator {
    LiquidateParams memory liquidateParams = LiquidateParams(
      ERC20(_getUnderlying(_poolTokenCollateralAddress)),
      ERC20(_getUnderlying(_poolTokenBorrowedAddress)),
      IAToken(_poolTokenCollateralAddress),
      IAToken(_poolTokenBorrowedAddress),
      msg.sender,
      _borrower,
      _repayAmount
    );

    uint256 seized;
    // If the liquidator already holds the borrowed underlying, do a direct liquidation.
    if (liquidateParams.borrowedUnderlying.balanceOf(msg.sender) >= _repayAmount) {
      liquidateParams.borrowedUnderlying.safeTransferFrom(msg.sender, address(this), _repayAmount);
      seized = _liquidateInternal(liquidateParams);
      uint256 balanceBefore = liquidateParams.collateralUnderlying.balanceOf(address(this));
      liquidateParams.collateralUnderlying.safeTransfer(msg.sender, balanceBefore);
    } else {
      // Otherwise, initiate flashloan-based liquidation.
      FlashLoanParams memory params = FlashLoanParams(
        address(liquidateParams.collateralUnderlying),
        address(liquidateParams.borrowedUnderlying),
        address(liquidateParams.poolTokenCollateral),
        address(liquidateParams.poolTokenBorrowed),
        liquidateParams.liquidator,
        liquidateParams.borrower,
        liquidateParams.toRepay,
        _swapData
      );
      seized = _liquidateWithFlashLoan(params);
      // After swap, any excess borrowed token is returned to the liquidator.
      uint256 balanceBefore = liquidateParams.borrowedUnderlying.balanceOf(address(this));
      liquidateParams.borrowedUnderlying.safeTransfer(msg.sender, balanceBefore);
    }
    emit Liquidated(msg.sender, liquidateParams.borrower, _poolTokenBorrowedAddress, _poolTokenCollateralAddress, liquidateParams.toRepay, seized, false);
  }

  /// @notice Internal direct liquidation (no flashloan)
  function _liquidateInternal(LiquidateParams memory _params) internal returns (uint256 seized) {
    uint256 balanceBefore = _params.collateralUnderlying.balanceOf(address(this));
    _params.borrowedUnderlying.safeApprove(address(aavePool), _params.toRepay);
    aavePool.liquidationCall(
      address(_params.poolTokenCollateral),
      address(_params.poolTokenBorrowed),
      _params.borrower,
      _params.toRepay,
      false
    );
    seized = _params.collateralUnderlying.balanceOf(address(this)) - balanceBefore;
    return seized;
  }

  /// @notice Internal liquidation that uses a flashloan.
  function _liquidateWithFlashLoan(FlashLoanParams memory _params) internal returns (uint256 seized) {
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = _params.toLiquidate;
    address[] memory tokens = new address[](1);
    tokens[0] = _params.borrowedUnderlying;

    bytes memory data = abi.encode(_params);

    if (flashLoanProvider == FlashLoanProvider.Aave) {
      // Use Aave-style flashloan
      uint256[] memory interestRateModes = new uint256[](1);
      interestRateModes[0] = 0; // 0 = no debt
      uint256 balanceBefore = ERC20(_params.collateralUnderlying).balanceOf(address(this));
      aavePool.flashLoan(
        address(this),
        tokens,
        amounts,
        interestRateModes,
        address(this),
        data,
        0
      );
      seized = ERC20(_params.collateralUnderlying).balanceOf(address(this)) - balanceBefore;
      emit FlashLoanTaken(msg.sender, amounts[0]);
    } else if (flashLoanProvider == FlashLoanProvider.Balancer) {
      // Use Balancer-style flashloan (assumes IBalancerFlashLoan interface)
      uint256 balanceBefore = ERC20(_params.collateralUnderlying).balanceOf(address(this));
      balancerFlashLoan.flashLoan(
        IERC3156FlashBorrower(address(this)),
        tokens,
        amounts,
        data
      );
      seized = ERC20(_params.collateralUnderlying).balanceOf(address(this)) - balanceBefore;
      emit FlashLoanTaken(msg.sender, amounts[0]);
    } else {
      revert UnknownLender();
    }
    return seized;
  }

  function _getUnderlying(address _poolToken) internal view returns (address) {
    // For simplicity we assume the _poolToken is the underlying asset.
    return _poolToken;
  }

  /// @notice Aave/Balancer flashloan callback.
  function executeOperation(
    address[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    address initiator,
    bytes calldata data
  ) external override returns (bool) {
    // Ensure the caller is the expected flashloan provider.
    if (flashLoanProvider == FlashLoanProvider.Aave) {
      require(msg.sender == address(aavePool), "Unknown lender");
    } else if (flashLoanProvider == FlashLoanProvider.Balancer) {
      require(msg.sender == address(balancerFlashLoan), "Unknown lender");
    }
    require(initiator == address(this), "Unknown initiator");

    FlashLoanParams memory params = abi.decode(data, (FlashLoanParams));
    _flashLoanInternal(params, amounts[0], feeAmounts[0]);
    return true;
  }

  function _flashLoanInternal(FlashLoanParams memory _params, uint256 _amount, uint256 _fee) internal {
    LiquidateParams memory liquidateParams = LiquidateParams(
      ERC20(_params.collateralUnderlying),
      ERC20(_params.borrowedUnderlying),
      IAToken(_params.poolTokenCollateral),
      IAToken(_params.poolTokenBorrowed),
      _params.liquidator,
      _params.borrower,
      _params.toLiquidate
    );

    uint256 seized = _liquidateInternal(liquidateParams);

    // If the borrowed and collateral tokens differ, perform a swap via Paraswap.
    if (_params.borrowedUnderlying != _params.collateralUnderlying) {
      // Here we call Paraswap instead of your internal SwapController.
      uint256 expectedReturn = paraswap.getExpectedReturn(_params.collateralUnderlying, _params.borrowedUnderlying, seized, _params.swapData);
      uint256 minReturn = (expectedReturn * (BASIS_POINTS - slippageTolerance)) / BASIS_POINTS;
      // Approve Paraswap to spend the seized tokens.
      ERC20(_params.collateralUnderlying).safeApprove(address(paraswap), seized);
      // The Paraswap swap function might be payable if using ETH; adjust as needed.
      uint256 amountReceived = paraswap.swap(_params.collateralUnderlying, _params.borrowedUnderlying, seized, minReturn, _params.swapData);
      require(amountReceived >= _amount + _fee, "Not enough to repay flashloan");
    }

    // Repay the flashloan. For Aave the pool pulls the funds (after approval).
    ERC20(_params.borrowedUnderlying).safeApprove(
      flashLoanProvider == FlashLoanProvider.Aave ? address(aavePool) : address(balancerFlashLoan),
      _amount + _fee
    );
    // Any excess funds can be sent to the liquidator.
    uint256 excess = ERC20(_params.borrowedUnderlying).balanceOf(address(this)) - (_amount + _fee);
    if (excess > 0) {
      ERC20(_params.borrowedUnderlying).safeTransfer(_params.liquidator, excess);
    }
    emit Liquidated(_params.liquidator, _params.borrower, _params.poolTokenBorrowed, _params.collateralUnderlying, _params.toLiquidate, seized, true);
  }
}
