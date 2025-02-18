// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMaverickV2Pool} from 'src/core/contracts/interfaces/IMaverickV2Pool.sol';
import {IMaverickV2Factory} from 'src/core/contracts/interfaces/IMaverickV2Factory.sol';
import {IMaverickV2Quoter} from 'src/core/contracts/interfaces/IMaverickV2Quoter.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract MaverickSwap is Ownable {
  // Uniswap V3 Swap Router
  IMaverickV2Quoter public immutable quoter;
  IMaverickV2Factory public immutable factory;

  // Minimum swap amount to prevent dust transactions
  uint256 public constant MIN_SWAP_AMOUNT = 1;

  // Events for tracking swaps
  event TokensSwapped(
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );

  event QuoteReceived(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 expectedAmountOut
  );

  constructor(address _swapFactoryAddress, address _swapQuoter) Ownable(msg.sender) {
    factory = IMaverickV2Factory(_swapFactoryAddress);
    quoter = IMaverickV2Quoter(_swapQuoter);
  }

  /**
   * @dev Performs a swap on Uniswap V3
   * @param tokenIn Address of the input token
   * @param tokenOut Address of the output token
   * @param amountIn Amount of input tokens to swap
   * @param amountOutMinimum Minimum amount of output tokens expected
   * @param poolFee Pool fee tier for the swap (e.g., 3000 for 0.3%)
   */
  function swap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOutMinimum,
    uint24 poolFee
  ) external returns (uint256) {
    IMaverickV2Pool pool = _getPool(tokenIn, tokenOut);
    // Validate inputs
    require(amountIn >= MIN_SWAP_AMOUNT, 'Swap amount too low');
    require(tokenIn != address(0) && tokenOut != address(0), 'Invalid token address');

    // Transfer tokens from sender to contract
    IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

    IERC20(tokenIn).transfer(address(pool), amountIn);

    // swapping weth in and weth is tokenA() in the pool
    bool tokenAIn = pool.tokenA() == IERC20(tokenIn);
    IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
      amount: amountIn,
      tokenAIn: tokenAIn,
      exactOutput: false,
      tickLimit: tokenAIn ? type(int32).max : type(int32).min
    });

    // swaps without a callback as the assets are already on the pool
    (, uint256 amountOut) = pool.swap(address(this), swapParams, bytes(''));

    require(amountOut >= amountOutMinimum, 'Output amount too low');

    IERC20(tokenOut).approve(msg.sender, amountOut);

    // Emit swap event
    emit TokensSwapped(tokenIn, tokenOut, amountIn, amountOut);

    return amountOut;
  }

  /**
   * @dev Retrieves a quote for a potential swap
   * @param tokenIn Address of the input token
   * @param tokenOut Address of the output token
   * @param amountIn Amount of input tokens to swap
   * @param poolFee Pool fee tier for the swap
   * @return expectedAmountOut Expected output amount
   */
  function getQuote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint24 poolFee
  ) external returns (uint256) {
    // Validate inputs
    IMaverickV2Pool pool = _getPool(tokenIn, tokenOut);
    require(amountIn >= MIN_SWAP_AMOUNT, 'Swap amount too low');
    require(tokenIn != address(0) && tokenOut != address(0), 'Invalid token address');

    bool tokenAIn = pool.tokenA() == IERC20(tokenIn);
    (, uint256 expectedAmountOut, ) = quoter.calculateSwap(
      pool,
      uint128(amountIn),
      tokenAIn,
      false,
      tokenAIn ? type(int32).max : type(int32).min
    );

    return expectedAmountOut;
  }

  function _getPool(address tokenIn, address tokenOut) internal view returns (IMaverickV2Pool) {
    IMaverickV2Pool[] memory pools = factory.lookup(IERC20(tokenIn), IERC20(tokenOut), 0, 1);

    if (pools.length > 0) {
      return pools[0];
    }

    revert();
  }

  /**
   * @dev Rescue tokens accidentally sent to the contract
   */
  function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
    IERC20 token = IERC20(tokenAddress);
    token.transfer(owner(), amount);
  }

  /**
   * @dev Fallback function to prevent accidental ETH transfers
   */
  receive() external payable {
    revert('Direct ETH transfers not allowed');
  }
}
