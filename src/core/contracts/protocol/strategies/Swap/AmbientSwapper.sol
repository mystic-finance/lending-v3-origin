// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface IAaveOracle {
  function getAssetPrice(address asset) external view returns (uint256);
}

interface ICrocSwapRouter {
  function swap(
    address base,
    address quote,
    uint256 poolIdx,
    bool isBuy,
    bool inBaseQty,
    uint128 qty,
    uint16 tip,
    uint128 limitPrice,
    uint128 minOut,
    uint8 settleFlags
  ) external payable returns (int128 baseFlow, int128 quoteFlow);
}

contract AmbientSwap is Ownable {
  using SafeERC20 for IERC20;

  struct SwapParams {
    address base;
    address quote;
    uint256 amountIn;
    uint256 amountOutMinimum;
    bool isBuy;
    uint24 fee;
  }

  // Croc Swap Router
  ICrocSwapRouter public immutable swapRouter;
  IAaveOracle public immutable aaveOracle;

  // Minimum swap amount to prevent dust transactions
  uint256 public constant MIN_SWAP_AMOUNT = 1;

  // Default pool index
  uint256 public constant DEFAULT_POOL_INDEX = 420;
  uint128 MAX_PRICE = 21267430153580247136652501917186561137;

  // Events for tracking swaps
  event TokensSwapped(
    address indexed base,
    address indexed quote,
    uint256 amountIn,
    int256 amountOut,
    bool isBuy
  );

  event QuoteReceived(address base, address quote, uint256 amountIn, uint256 expectedAmountOut);

  constructor(address _swapRouterAddress, address _pool) Ownable(msg.sender) {
    swapRouter = ICrocSwapRouter(_swapRouterAddress);
    aaveOracle = IAaveOracle(IPool(_pool).ADDRESSES_PROVIDER().getPriceOracle());
  }

  /**
   * @dev Performs a swap on Ambient (Croc) swap router
   * @param base Address of the base token
   * @param quote Address of the quote token
   * @param amountIn Amount of input tokens to swap
   * @param amountOutMinimum Minimum amount of output tokens expected
   */

  function swap(
    address base,
    address quote,
    uint256 amountIn,
    uint256 amountOutMinimum,
    uint24 fee
  ) external returns (int256 amountOut) {
    // Pack parameters into struct to save stack space
    SwapParams memory params = SwapParams({
      base: base,
      quote: quote,
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      isBuy: base < quote,
      fee: fee
    });

    // Validate inputs
    _validateInputs(params);

    // Handle token transfers and approvals
    _handleTokens(params);

    // Perform the swap
    amountOut = _performSwap(params);

    // Handle final approvals and emit event
    _finalizeSwap(params, amountOut);

    return amountOut;
  }

  function _validateInputs(SwapParams memory params) internal pure {
    require(params.amountIn >= MIN_SWAP_AMOUNT, 'Swap amount too low');
    require(params.base != address(0) && params.quote != address(0), 'Invalid token address');
  }

  function _handleTokens(SwapParams memory params) internal {
    IERC20(params.base).safeTransferFrom(msg.sender, address(this), params.amountIn);
    IERC20(params.base).approve(address(swapRouter), params.amountIn);
  }

  function _performSwap(SwapParams memory params) internal returns (int256) {
    try
      swapRouter.swap(
        params.isBuy ? params.base : params.quote,
        params.isBuy ? params.quote : params.base,
        DEFAULT_POOL_INDEX,
        params.isBuy,
        params.isBuy ? true : false,
        uint128(params.amountIn),
        0, // tip
        params.isBuy ? MAX_PRICE : 0, // limitPrice
        uint128(params.amountOutMinimum),
        0 // settleFlags
      )
    returns (int128 baseFlow, int128 quoteFlow) {
      // uint128(params.isBuy ? aaveOracle.getAssetPrice(params.base) : 0)
      return
        !params.isBuy
          ? int256(baseFlow > 0 ? baseFlow : -baseFlow)
          : int256(quoteFlow > 0 ? quoteFlow : -quoteFlow);
    } catch Error(string memory) {
      // Catch standard errors
      return _oppSwap(params);
    } catch Panic(uint) {
      // Catch panics
      return _oppSwap(params);
    } catch (bytes memory) {
      // Catch low-level errors
      return _oppSwap(params);
    }
  }

  function _oppSwap(SwapParams memory params) internal returns (int256) {
    (int128 baseFlow, int128 quoteFlow) = swapRouter.swap(
      !params.isBuy ? params.base : params.quote,
      !params.isBuy ? params.quote : params.base,
      DEFAULT_POOL_INDEX,
      !params.isBuy,
      !params.isBuy ? false : true,
      uint128(params.amountIn),
      0,
      !params.isBuy ? 0 : MAX_PRICE,
      uint128(params.amountOutMinimum),
      0
    );

    return
      params.isBuy
        ? int256(baseFlow > 0 ? baseFlow : -baseFlow)
        : int256(quoteFlow > 0 ? quoteFlow : -quoteFlow);
  }

  function _finalizeSwap(SwapParams memory params, int256 amountOut) internal {
    IERC20(params.quote).approve(msg.sender, uint256(amountOut));
    emit TokensSwapped(params.base, params.quote, params.amountIn, amountOut, params.isBuy);
  }

  /**
   * @dev Retrieves a simulated quote for a potential swap
   * @param tokenIn Address of the base token
   * @param tokenOut Address of the quote token
   * @param amountIn Amount of input tokens to swap
   * @return expectedAmountOut Expected output amount
   */
  function getQuote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint24 poolFee
  ) external view returns (uint256 expectedAmountOut) {
    // uint  poolFee = 500;
    // Get token prices and decimals
    uint256 tokenInPrice = aaveOracle.getAssetPrice(tokenIn);
    uint256 tokenOutPrice = aaveOracle.getAssetPrice(tokenOut);
    uint256 tokenInDecimals = IERC20Metadata(tokenIn).decimals();
    uint256 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();

    // Calculate USD value of input amount (8 decimals precision from Aave Oracle)
    uint256 inputValueInUsd = (amountIn * tokenInPrice) / 10 ** tokenInDecimals;

    // Apply 0.3% slippage to USD value
    uint256 outputValueInUsd = (inputValueInUsd * (10000 - poolFee)) / 10000;

    // Convert USD value to output token amount
    uint256 amountOut = (outputValueInUsd * 10 ** tokenOutDecimals) / tokenOutPrice;

    return amountOut;
  }

  /**
   * @dev Simulated quote function (replace with actual quote logic)
   */
  function _simulateQuote(
    address base,
    address quote,
    uint256 amountIn,
    bool isBuy
  ) internal pure returns (uint256) {
    // Placeholder implementation - in reality, this would interact with
    // an on-chain price oracle or quoter
    // This is just a simple example and should NOT be used in production
    return isBuy ? (amountIn * 95) / 100 : (amountIn * 105) / 100;
  }

  /**
   * @dev Rescue tokens accidentally sent to the contract
   */
  function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
    IERC20(tokenAddress).safeTransfer(owner(), amount);
  }

  /**
   * @dev Fallback function to prevent accidental ETH transfers
   */
  receive() external payable {
    revert('Direct ETH transfers not allowed');
  }
}
