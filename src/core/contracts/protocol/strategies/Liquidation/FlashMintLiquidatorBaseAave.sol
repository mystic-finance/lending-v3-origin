// // SPDX-License-Identifier: GNU AGPLv3
// pragma solidity 0.8.20;

// import 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
// import 'src/core/contracts/interfaces/IPriceOracleGetter.sol';
// import 'src/core/contracts/interfaces/IAToken.sol';
// import 'src/core/contracts/interfaces/IPool.sol';
// import 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

// import 'src/core/contracts/protocol/libraries/math/PercentageMath.sol';

// import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
// import '@openzeppelin/contracts/access/Ownable.sol';
// import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

// /// @title CompoundMath.
// /// @dev Library emulating in solidity 8+ the behavior of Compound's mulScalarTruncate and divScalarByExpTruncate functions.
// library CompoundMath {
//   /// ERRORS ///

//   /// @notice Reverts when the number exceeds 224 bits.
//   error NumberExceeds224Bits();

//   /// @notice Reverts when the number exceeds 32 bits.
//   error NumberExceeds32Bits();

//   /// INTERNAL ///

//   function mul(uint256 x, uint256 y) internal pure returns (uint256) {
//     return (x * y) / 1e18;
//   }

//   function div(uint256 x, uint256 y) internal pure returns (uint256) {
//     return ((1e18 * x * 1e18) / y) / 1e18;
//   }

//   function safe224(uint256 n) internal pure returns (uint224) {
//     if (n >= 2 ** 224) revert NumberExceeds224Bits();
//     return uint224(n);
//   }

//   function safe32(uint256 n) internal pure returns (uint32) {
//     if (n >= 2 ** 32) revert NumberExceeds32Bits();
//     return uint32(n);
//   }

//   function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
//     return
//       a < b
//         ? a < c
//           ? a
//           : c
//         : b < c
//           ? b
//           : c;
//   }

//   function min(uint256 a, uint256 b) internal pure returns (uint256) {
//     return a < b ? a : b;
//   }

//   function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
//     return a >= b ? a - b : 0;
//   }
// }

// interface IERC3156FlashBorrower {
//   /**
//    * @dev Receive a flash loan.
//    * @param initiator The initiator of the loan.
//    * @param token The loan currency.
//    * @param amount The amount of tokens lent.
//    * @param fee The additional amount of tokens to repay.
//    * @param data Arbitrary data structure, intended to contain user-defined parameters.
//    * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
//    */
//   function onFlashLoan(
//     address initiator,
//     address token,
//     uint256 amount,
//     uint256 fee,
//     bytes calldata data
//   ) external returns (bytes32);

//   function receiveFlashLoan(
//     address[] memory tokens,
//     uint256[] memory _amounts,
//     uint256[] memory _feeAmounts,
//     bytes calldata data
//   ) external returns (bytes32);
// }

// interface IERC3156FlashLender {
//   /**
//    * @dev The amount of currency available to be lent.
//    * @param token The loan currency.
//    * @return The amount of `token` that can be borrowed.
//    */
//   function maxFlashLoan(address token) external view returns (uint256);

//   /**
//    * @dev The fee to be charged for a given loan.
//    * @param token The loan currency.
//    * @param amount The amount of tokens lent.
//    * @return The amount of `token` to be charged for the loan, on top of the returned principal.
//    */
//   function flashFee(address token, uint256 amount) external view returns (uint256);

//   /**
//    * @dev Initiate a flash loan.
//    * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
//    * @param token The loan currency.
//    * @param amount The amount of tokens lent.
//    * @param data Arbitrary data structure, intended to contain user-defined parameters.
//    */
//   function flashLoan(
//     IERC3156FlashBorrower receiver,
//     address[] memory token,
//     uint256[] memory amount,
//     bytes calldata data
//   ) external returns (bool);
// }

// library SafeTransferLib {
//   /*//////////////////////////////////////////////////////////////
//                              ETH OPERATIONS
//     //////////////////////////////////////////////////////////////*/

//   function safeTransferETH(address to, uint256 amount) internal {
//     bool success;

//     assembly {
//       // Transfer the ETH and store if it succeeded or not.
//       success := call(gas(), to, amount, 0, 0, 0, 0)
//     }

//     require(success, 'ETH_TRANSFER_FAILED');
//   }

//   /*//////////////////////////////////////////////////////////////
//                             ERC20 OPERATIONS
//     //////////////////////////////////////////////////////////////*/

//   function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) internal {
//     bool success;

//     assembly {
//       // Get a pointer to some free memory.
//       let freeMemoryPointer := mload(0x40)

//       // Write the abi-encoded calldata into memory, beginning with the function selector.
//       mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
//       mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
//       mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
//       mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

//       success := and(
//         // Set success to whether the call reverted, if not we check it either
//         // returned exactly 1 (can't just be non-zero data), or had no return data.
//         or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
//         // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
//         // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
//         // Counterintuitively, this call must be positioned second to the or() call in the
//         // surrounding and() call or else returndatasize() will be zero during the computation.
//         call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
//       )
//     }

//     require(success, 'TRANSFER_FROM_FAILED');
//   }

//   function safeTransfer(ERC20 token, address to, uint256 amount) internal {
//     bool success;

//     assembly {
//       // Get a pointer to some free memory.
//       let freeMemoryPointer := mload(0x40)

//       // Write the abi-encoded calldata into memory, beginning with the function selector.
//       mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
//       mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
//       mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

//       success := and(
//         // Set success to whether the call reverted, if not we check it either
//         // returned exactly 1 (can't just be non-zero data), or had no return data.
//         or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
//         // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
//         // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
//         // Counterintuitively, this call must be positioned second to the or() call in the
//         // surrounding and() call or else returndatasize() will be zero during the computation.
//         call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
//       )
//     }

//     require(success, 'TRANSFER_FAILED');
//   }

//   function safeApprove(ERC20 token, address to, uint256 amount) internal {
//     bool success;

//     assembly {
//       // Get a pointer to some free memory.
//       let freeMemoryPointer := mload(0x40)

//       // Write the abi-encoded calldata into memory, beginning with the function selector.
//       mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
//       mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
//       mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

//       success := and(
//         // Set success to whether the call reverted, if not we check it either
//         // returned exactly 1 (can't just be non-zero data), or had no return data.
//         or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
//         // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
//         // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
//         // Counterintuitively, this call must be positioned second to the or() call in the
//         // surrounding and() call or else returndatasize() will be zero during the computation.
//         call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
//       )
//     }

//     require(success, 'APPROVE_FAILED');
//   }
// }

// interface IWETH {
//   function deposit() external payable;

//   function withdraw(uint256) external;
// }

// contract SharedLiquidator is Ownable {
//   mapping(address => bool) public isLiquidator;

//   error OnlyLiquidator();

//   event LiquidatorAdded(address indexed _liquidatorAdded);

//   event LiquidatorRemoved(address indexed _liquidatorRemoved);

//   event Withdrawn(
//     address indexed sender,
//     address indexed receiver,
//     address indexed underlyingAddress,
//     uint256 amount
//   );

//   modifier onlyLiquidator() {
//     if (!isLiquidator[msg.sender]) revert OnlyLiquidator();
//     _;
//   }

//   constructor() {
//     isLiquidator[msg.sender] = true;
//     emit LiquidatorAdded(msg.sender);
//   }

//   function addLiquidator(address _newLiquidator) external onlyOwner {
//     isLiquidator[_newLiquidator] = true;
//     emit LiquidatorAdded(_newLiquidator);
//   }

//   function removeLiquidator(address _liquidatorToRemove) external onlyOwner {
//     isLiquidator[_liquidatorToRemove] = false;
//     emit LiquidatorRemoved(_liquidatorToRemove);
//   }

//   function withdraw(
//     address _underlyingAddress,
//     address _receiver,
//     uint256 _amount
//   ) external onlyOwner {
//     uint256 amountMax = ERC20(_underlyingAddress).balanceOf(address(this));
//     uint256 amount = _amount > amountMax ? amountMax : _amount;
//     ERC20(_underlyingAddress).transfer(_receiver, amount);
//     emit Withdrawn(msg.sender, _receiver, _underlyingAddress, amount);
//   }
// }

// abstract contract FlashMintLiquidatorBaseAave is
//   ReentrancyGuard,
//   SharedLiquidator,
//   IERC3156FlashBorrower
// {
//   using SafeTransferLib for ERC20;
//   using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
//   using CompoundMath for uint256;
//   using PercentageMath for uint256;

//   struct FlashLoanParams {
//     address collateralUnderlying;
//     address borrowedUnderlying;
//     address poolTokenCollateral;
//     address poolTokenBorrowed;
//     address liquidator;
//     address borrower;
//     uint256 toLiquidate;
//     bytes path;
//   }

//   struct LiquidateParams {
//     ERC20 collateralUnderlying;
//     ERC20 borrowedUnderlying;
//     IAToken poolTokenCollateral;
//     IAToken poolTokenBorrowed;
//     address liquidator;
//     address borrower;
//     uint256 toRepay;
//   }

//   error ValueAboveBasisPoints();

//   error UnknownLender();

//   error UnknownInitiator();

//   error NoProfitableLiquidation();

//   event Liquidated(
//     address indexed liquidator,
//     address borrower,
//     address indexed poolTokenBorrowedAddress,
//     address indexed poolTokenCollateralAddress,
//     uint256 amount,
//     uint256 seized,
//     bool usingFlashLoan
//   );

//   event FlashLoan(address indexed initiator, uint256 amount);

//   event OverSwappedDai(uint256 amount);

//   uint256 public constant BASIS_POINTS = 10_000;
//   bytes32 public constant FLASHLOAN_CALLBACK = keccak256('ERC3156FlashBorrower.onFlashLoan');
//   uint256 public constant DAI_DECIMALS = 18;
//   uint256 public slippageTolerance; // in BASIS_POINTS units

//   IERC3156FlashLender public immutable lender;
//   // IMorpho public immutable morpho;
//   IPoolAddressesProvider public immutable addressesProvider;
//   IPool public immutable lendingPool;
//   IAToken public immutable aDai;
//   ERC20 public immutable dai;

//   constructor(
//     IERC3156FlashLender _lender,
//     // IMorpho _morpho,
//     IPoolAddressesProvider _addressesProvider,
//     IAToken _aDai
//   ) SharedLiquidator() {
//     lender = _lender;
//     // morpho = _morpho;
//     addressesProvider = _addressesProvider;
//     lendingPool = IPool(_addressesProvider.getPool());
//     aDai = _aDai;
//     dai = ERC20(_aDai.UNDERLYING_ASSET_ADDRESS());
//   }

//   function _liquidateInternal(
//     LiquidateParams memory _liquidateParams
//   ) internal returns (uint256 seized_) {
//     uint256 balanceBefore = _liquidateParams.collateralUnderlying.balanceOf(address(this));
//     _liquidateParams.borrowedUnderlying.safeApprove(address(lendingPool), _liquidateParams.toRepay);
//     lendingPool.liquidationCall(
//       address(_liquidateParams.poolTokenCollateral),
//       address(_liquidateParams.poolTokenBorrowed),
//       _liquidateParams.borrower,
//       _liquidateParams.toRepay,
//       true
//     );
//     seized_ = _liquidateParams.collateralUnderlying.balanceOf(address(this)) - balanceBefore;
//     emit Liquidated(
//       msg.sender,
//       _liquidateParams.borrower,
//       address(_liquidateParams.poolTokenBorrowed),
//       address(_liquidateParams.poolTokenCollateral),
//       _liquidateParams.toRepay,
//       seized_,
//       false
//     );
//   }

//   function _liquidateWithFlashLoan(
//     FlashLoanParams memory _flashLoanParams
//   ) internal returns (uint256 seized_) {
//     bytes memory data = _encodeData(_flashLoanParams);

//     uint256 daiToFlashLoan = _getDaiToFlashloan(
//       _flashLoanParams.borrowedUnderlying,
//       _flashLoanParams.toLiquidate
//     );

//     dai.safeApprove(
//       address(lender),
//       daiToFlashLoan + lender.flashFee(address(dai), daiToFlashLoan)
//     );

//     uint256 balanceBefore = ERC20(_flashLoanParams.collateralUnderlying).balanceOf(address(this));

//     uint256[] memory daiToFlashLoanArr;
//     daiToFlashLoanArr[0] = daiToFlashLoan;

//     address[] memory daiArr;
//     daiArr[0] = address(dai);

//     lender.flashLoan(this, daiArr, daiToFlashLoanArr, data);

//     seized_ = ERC20(_flashLoanParams.collateralUnderlying).balanceOf(address(this)) - balanceBefore;

//     emit FlashLoan(msg.sender, daiToFlashLoan);
//   }

//   function _getDaiToFlashloan(
//     address _underlyingToRepay,
//     uint256 _amountToRepay
//   ) internal view returns (uint256 amountToFlashLoan_) {
//     if (_underlyingToRepay == address(dai)) {
//       amountToFlashLoan_ = _amountToRepay;
//     } else {
//       IPriceOracleGetter oracle = IPriceOracleGetter(addressesProvider.getPriceOracle());

//       (uint256 loanToValue, , , , ) = lendingPool.getConfiguration(address(dai)).getParamsMemory();
//       uint256 daiPrice = oracle.getAssetPrice(address(dai));
//       uint256 borrowedTokenPrice = oracle.getAssetPrice(_underlyingToRepay);
//       uint256 underlyingDecimals = ERC20(_underlyingToRepay).decimals();
//       amountToFlashLoan_ =
//         (((_amountToRepay * borrowedTokenPrice * 10 ** DAI_DECIMALS) /
//           daiPrice /
//           10 ** underlyingDecimals) * BASIS_POINTS) /
//         loanToValue +
//         1e18; // for rounding errors of supply/borrow on aave
//     }
//   }

//   function _encodeData(
//     FlashLoanParams memory _flashLoanParams
//   ) internal pure returns (bytes memory data) {
//     data = abi.encode(
//       _flashLoanParams.collateralUnderlying,
//       _flashLoanParams.borrowedUnderlying,
//       _flashLoanParams.poolTokenCollateral,
//       _flashLoanParams.poolTokenBorrowed,
//       _flashLoanParams.liquidator,
//       _flashLoanParams.borrower,
//       _flashLoanParams.toLiquidate,
//       _flashLoanParams.path
//     );
//   }

//   function _decodeData(
//     bytes calldata data
//   ) internal pure returns (FlashLoanParams memory _flashLoanParams) {
//     (
//       _flashLoanParams.collateralUnderlying,
//       _flashLoanParams.borrowedUnderlying,
//       _flashLoanParams.poolTokenCollateral,
//       _flashLoanParams.poolTokenBorrowed,
//       _flashLoanParams.liquidator,
//       _flashLoanParams.borrower,
//       _flashLoanParams.toLiquidate,
//       _flashLoanParams.path
//     ) = abi.decode(data, (address, address, address, address, address, address, uint256, bytes));
//   }

//   function _getUnderlying(address _poolToken) internal view returns (ERC20 underlying_) {
//     underlying_ = ERC20(IAToken(_poolToken).UNDERLYING_ASSET_ADDRESS());
//   }
// }

// // add optional swap for non popular asset tokens after popular flashloan
// // add optional calldata for no integratable uniswap swaps
// // add optional swap/redeem for seized tokens maybe calldata?
