pragma solidity 0.8.20;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
import 'src/core/contracts/interfaces/IPriceOracleGetter.sol';
import 'src/core/contracts/interfaces/IAToken.sol';
import 'src/core/contracts/interfaces/IPool.sol';
import 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {SwapController} from '../SwapController.sol';
import {FlashLoanController} from '../FlashLoanController.sol';

import 'src/core/contracts/protocol/libraries/math/PercentageMath.sol';
import "./ILendingProvider.sol";

/// @title CompoundMath.
/// @dev Library emulating in solidity 8+ the behavior of Compound's mulScalarTruncate and divScalarByExpTruncate functions.
library CompoundMath {
  /// ERRORS ///

  /// @notice Reverts when the number exceeds 224 bits.
  error NumberExceeds224Bits();

  /// @notice Reverts when the number exceeds 32 bits.
  error NumberExceeds32Bits();

  /// INTERNAL ///

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
    return
      a < b
        ? a < c
          ? a
          : c
        : b < c
          ? b
          : c;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a - b : 0;
  }
}

interface IERC3156FlashBorrower {
  // /**
  //  * @dev Receive a flash loan.
  //  * @param initiator The initiator of the loan.
  //  * @param token The loan currency.
  //  * @param amount The amount of tokens lent.
  //  * @param fee The additional amount of tokens to repay.
  //  * @param data Arbitrary data structure, intended to contain user-defined parameters.
  //  * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
  //  */
  // function onFlashLoan(
  //   address initiator,
  //   address token,
  //   uint256 amount,
  //   uint256 fee,
  //   bytes calldata data
  // ) external returns (bytes32);

  function executeOperation(
    address[] memory tokens,
    uint256[] memory _amounts,
    uint256[] memory _feeAmounts,
    address borrower,
    bytes calldata data
  ) external returns (bool);

  // function receiveFlashLoan(
  //   address[] memory tokens,
  //   uint256[] memory _amounts,
  //   uint256[] memory _feeAmounts,
  //   bytes calldata data
  // ) external returns (bytes32);
}

interface IERC3156FlashLender {
  /**
   * @dev The amount of currency available to be lent.
   * @param token The loan currency.
   * @return The amount of `token` that can be borrowed.
   */
  function maxFlashLoan(address token) external view returns (uint256);

  /**
   * @dev The fee to be charged for a given loan.
   * @param token The loan currency.
   * @param amount The amount of tokens lent.
   * @return The amount of `token` to be charged for the loan, on top of the returned principal.
   */
  function flashFee(address token, uint256 amount) external view returns (uint256);

  /**
   * @dev Initiate a flash loan.
   * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
   * @param token The loan currency.
   * @param amount The amount of tokens lent.
   * @param data Arbitrary data structure, intended to contain user-defined parameters.
   */
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address[] memory token,
    uint256[] memory amount,
    bytes calldata data
  ) external returns (bool);
}

library SafeTransferLib {
  /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferETH(address to, uint256 amount) internal {
    bool success;

    assembly {
      // Transfer the ETH and store if it succeeded or not.
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }

    require(success, 'ETH_TRANSFER_FAILED');
  }

  /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
      mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
      )
    }

    require(success, 'TRANSFER_FROM_FAILED');
  }

  function safeTransfer(ERC20 token, address to, uint256 amount) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, 'TRANSFER_FAILED');
  }

  function safeApprove(ERC20 token, address to, uint256 amount) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, 'APPROVE_FAILED');
  }
}

interface IWETH {
  function deposit() external payable;

  function withdraw(uint256) external;
}

contract FlashMintLiquidator is ReentrancyGuard, Ownable, IERC3156FlashBorrower {
  using SafeTransferLib for ERC20;
  using CompoundMath for uint256;
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  uint256 public constant BASIS_POINTS = 10_000;
  bytes32 public constant FLASHLOAN_CALLBACK = keccak256('ERC3156FlashBorrower.onFlashLoan');

  IPoolAddressesProvider public immutable addressesProvider;
  IPool public immutable lendingPool;
  SwapController public immutable swapController;
  uint256 public slippageTolerance;
  ILendingProvider[] public providers;


  event Liquidated(
    address indexed liquidator,
    address borrower,
    address indexed poolTokenBorrowedAddress,
    address indexed poolTokenCollateralAddress,
    uint256 amount,
    uint256 seized,
    bool usingFlashLoan
  );
  event FlashLoan(address indexed initiator, uint256 amount);
  event Swapped(
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );
  event SlippageToleranceSet(uint256 newTolerance);

    event ProviderAdded(address indexed provider);
    event ProviderRemoved(address indexed provider);
    event LiquidationExecuted(address indexed provider, address indexed borrower, uint256 repayAmount);


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
    bytes path;
    uint256 providerIndex;
  }

  struct LiquidateParams {
    ERC20 collateralUnderlying;
    ERC20 borrowedUnderlying;
    IAToken poolTokenCollateral;
    IAToken poolTokenBorrowed;
    address liquidator;
    address borrower;
    uint256 toRepay;
    uint256 providerIndex;
  }

  constructor(
    SwapController _swapController,
    IPoolAddressesProvider _addressesProvider,
    uint256 _slippageTolerance
  ) Ownable(msg.sender) {
    swapController = _swapController;
    addressesProvider = _addressesProvider;
    lendingPool = IPool(_addressesProvider.getPool());
    slippageTolerance = _slippageTolerance;
  }

  modifier onlyLiquidator() {
    require(msg.sender == owner(), 'Only liquidator can call this function');
    _;
  }

 
    function addProvider(ILendingProvider provider) external onlyOwner {
        providers.push(provider);
        emit ProviderAdded(address(provider));
    }

    function removeProvider(uint256 index) external onlyOwner {
        require(index < providers.length, "Invalid index");
        address removed = address(providers[index]);
        providers[index] = providers[providers.length - 1];
        providers.pop();
        emit ProviderRemoved(removed);
    }

    function compileLiquidateableUsers() external view returns (address[] memory allUsers, uint256[] memory allRepayAmounts) {
        uint256 totalCount = 0;
        for (uint256 i = 0; i < providers.length; i++) {
            (address[] memory users, ) = providers[i].getLiquidateableUsers();
            totalCount += users.length;
        }

        allUsers = new address[](totalCount);
        allRepayAmounts = new uint256[](totalCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < providers.length; i++) {
            (address[] memory users, uint256[] memory amounts) = providers[i].getLiquidateableUsers();
            for (uint256 j = 0; j < users.length; j++) {
                allUsers[counter] = users[j];
                allRepayAmounts[counter] = amounts[j];
                counter++;
            }
        }
    }

    function compileLiquidateableProviderUsers(uint256 _providerIndex) external view returns (address[] memory allUsers, uint256[] memory allRepayAmounts) {
        (address[] memory users, ) = providers[_providerIndex].getLiquidateableUsers();
        uint256 totalCount = users.length;

        allUsers = new address[](totalCount);
        allRepayAmounts = new uint256[](totalCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < providers.length; i++) {
            (address[] memory users, uint256[] memory amounts) = providers[i].getLiquidateableUsers();
            for (uint256 j = 0; j < users.length; j++) {
                allUsers[counter] = users[j];
                allRepayAmounts[counter] = amounts[j];
                counter++;
            }
        }
    }

  function setSlippageTolerance(uint256 _newTolerance) external onlyOwner {
    require(_newTolerance <= BASIS_POINTS, 'Value above basis points');
    slippageTolerance = _newTolerance;
    emit SlippageToleranceSet(_newTolerance);
  }

  function liquidate(
    uint256 providerIndex,
    address _poolTokenBorrowedAddress,
    address _poolTokenCollateralAddress,
    address _borrower,
    uint256 _repayAmount,
    bool _stakeTokens,
    bytes memory _path
  ) external nonReentrant onlyLiquidator {
    require(providerIndex < providers.length, "Invalid provider index");
    LiquidateParams memory liquidateParams = LiquidateParams(
      ERC20(_getUnderlying(_poolTokenCollateralAddress)),
      ERC20(_getUnderlying(_poolTokenBorrowedAddress)),
      IAToken(_poolTokenCollateralAddress),
      IAToken(_poolTokenBorrowedAddress),
      msg.sender,
      _borrower,
      _repayAmount,
      providerIndex
    );

    uint256 seized;
    if (liquidateParams.borrowedUnderlying.balanceOf(msg.sender) >= _repayAmount) {
      ERC20(liquidateParams.borrowedUnderlying).safeTransferFrom(
        msg.sender,
        address(this),
        _repayAmount
      );
      seized = _liquidateInternal(liquidateParams);
      uint256 balanceBefore = liquidateParams.collateralUnderlying.balanceOf(address(this));
      liquidateParams.collateralUnderlying.safeTransfer(msg.sender, balanceBefore);
    } else {
      FlashLoanParams memory params = FlashLoanParams(
        address(liquidateParams.collateralUnderlying),
        address(liquidateParams.borrowedUnderlying),
        address(liquidateParams.poolTokenCollateral),
        address(liquidateParams.poolTokenBorrowed),
        liquidateParams.liquidator,
        liquidateParams.borrower,
        liquidateParams.toRepay,
        _path,
        providerIndex
      );
      seized = _liquidateWithFlashLoan(params);
      uint256 balanceBefore = liquidateParams.borrowedUnderlying.balanceOf(address(this));
      liquidateParams.borrowedUnderlying.safeTransfer(msg.sender, balanceBefore);
    }
  }

  function _liquidateInternal(LiquidateParams memory _params) internal returns (uint256 seized) {
    ILendingProvider provider = providers[_params.providerIndex];
    uint256 balanceBefore = _params.collateralUnderlying.balanceOf(address(this));
    _params.borrowedUnderlying.safeApprove(address(provider), _params.toRepay);
    provider.liquidate(
      address(_params.poolTokenCollateral),
      address(_params.poolTokenBorrowed),
      _params.borrower,
      _params.toRepay,
      false
    );
    seized = _params.collateralUnderlying.balanceOf(address(this)) - balanceBefore;

    emit Liquidated(
      msg.sender,
      _params.borrower,
      address(_params.poolTokenBorrowed),
      address(_params.poolTokenCollateral),
      _params.toRepay,
      seized,
      false
    );
  }

  function _liquidateWithFlashLoan(
    FlashLoanParams memory _params
  ) internal returns (uint256 seized) {
    uint256 amountToFlashLoan = _getAmountToFlashloan(
      _params.borrowedUnderlying,
      _params.toLiquidate
    );
    bytes memory data = abi.encode(_params);

    uint256[] memory amountArr = new uint256[](1);
    amountArr[0] = _params.toLiquidate;

    address[] memory addressArr = new address[](1);
    addressArr[0] = _params.borrowedUnderlying;

    uint256[] memory interestRateModes = new uint256[](1);
    interestRateModes[0] = 0; // 0 = no debt, 1 = stable, 2 = variable

    uint256 balanceBefore = ERC20(_params.collateralUnderlying).balanceOf(address(this));
    lendingPool.flashLoan(
      address(this),
      addressArr,
      amountArr,
      interestRateModes,
      address(this),
      data,
      0
    );
    seized = ERC20(_params.collateralUnderlying).balanceOf(address(this)) - balanceBefore;

    emit FlashLoan(msg.sender, amountToFlashLoan);
  }

  function _getAmountToFlashloan(
    address _underlying,
    uint256 _amount
  ) internal view returns (uint256) {
    IPriceOracleGetter oracle = IPriceOracleGetter(addressesProvider.getPriceOracle());
    uint256 price = oracle.getAssetPrice(_underlying);
    return (_amount * price) / (10 ** ERC20(_underlying).decimals());
  }

  function _getUnderlying(address _poolToken) internal view returns (address) {
    return _poolToken; // Assuming _poolToken is the underlying asset address
  }

  function executeOperation(
    address[] memory tokens,
    uint256[] memory _amounts,
    uint256[] memory _feeAmounts,
    address borrower,
    bytes calldata data
  ) external override returns (bool) {
    require(msg.sender == address(lendingPool), 'Unknown lender');
    require(borrower == address(this), 'Unknown initiator');

    FlashLoanParams memory params = abi.decode(data, (FlashLoanParams));
    _flashLoanInternal(params, _amounts[0], _feeAmounts[0]);

    return true;
  }

  function _flashLoanInternal(
    FlashLoanParams memory _params,
    uint256 _amount,
    uint256 _fee
  ) internal {
    LiquidateParams memory liquidateParams = LiquidateParams(
      ERC20(_params.collateralUnderlying),
      ERC20(_params.borrowedUnderlying),
      IAToken(_params.poolTokenCollateral),
      IAToken(_params.poolTokenBorrowed),
      _params.liquidator,
      _params.borrower,
      _params.toLiquidate,
      _params.providerIndex
    );

    uint256 seized = _liquidateInternal(liquidateParams);

    if (_params.borrowedUnderlying != _params.collateralUnderlying) {
      (, , uint24 poolFee) = abi.decode(_params.path, (address, address, uint24));
      _doSwap(
        _params.poolTokenCollateral,
        _params.borrowedUnderlying,
        seized,
        _amount + _fee,
        poolFee
      );
    }

    uint256 totalBalance = ERC20(_params.borrowedUnderlying).balanceOf(address(this));
    ERC20(_params.borrowedUnderlying).safeApprove(address(lendingPool), _amount + _fee);
    ERC20(_params.borrowedUnderlying).safeTransfer(
      _params.liquidator,
      totalBalance - (_amount + _fee)
    );

    emit Liquidated(
      _params.liquidator,
      _params.borrower,
      _params.poolTokenBorrowed,
      _params.poolTokenCollateral,
      _params.toLiquidate,
      seized,
      true
    );
  }

  function _calculateMaxSwapInput(
    FlashLoanParams memory _params,
    uint256 _seized
  ) internal view returns (uint256) {
    IPriceOracleGetter oracle = IPriceOracleGetter(addressesProvider.getPriceOracle());
    uint256 collateralPrice = oracle.getAssetPrice(_params.collateralUnderlying);
    uint256 borrowedPrice = oracle.getAssetPrice(_params.borrowedUnderlying);
    return
      (_seized * collateralPrice * (BASIS_POINTS + slippageTolerance)) /
      (borrowedPrice * BASIS_POINTS);
  }

  function _doSwap(
    address tokenIn,
    address tokenOut,
    uint256 maxIn,
    uint256 amountOut,
    uint24 poolFee
  ) internal returns (uint256) {
    uint256 expectedAmountOut = swapController.getQuote(tokenIn, tokenOut, maxIn, poolFee);
    uint256 amountOutMinimum = (expectedAmountOut * (BASIS_POINTS - slippageTolerance)) /
      BASIS_POINTS;
    uint assetBalance = ERC20(tokenOut).balanceOf(address(this));
    require(assetBalance + amountOutMinimum > amountOut, 'Not enough to pay flashloan');

    ERC20(tokenIn).safeApprove(address(swapController), maxIn);
    uint256 amountIn = swapController.swap(tokenIn, tokenOut, maxIn, amountOutMinimum, poolFee);

    emit Swapped(tokenIn, tokenOut, maxIn, amountIn);
    return amountIn + assetBalance;
  }
}
