// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract UniswapSwap is Ownable {
  // Uniswap V3 Swap Router
  ISwapRouter public immutable swapRouter;

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

  constructor(address _swapRouterAddress) Ownable(msg.sender) {
    swapRouter = ISwapRouter(_swapRouterAddress);
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
  ) external returns (uint256 amountOut) {
    // Validate inputs
    require(amountIn >= MIN_SWAP_AMOUNT, 'Swap amount too low');
    require(tokenIn != address(0) && tokenOut != address(0), 'Invalid token address');

    // Transfer tokens from sender to contract
    IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

    // Approve router to spend tokens
    IERC20(tokenIn).approve(address(swapRouter), amountIn);

    // Prepare swap parameters
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: poolFee,
      recipient: msg.sender,
      deadline: block.timestamp,
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: 0
    });

    // Execute the swap
    amountOut = swapRouter.exactInputSingle(params);

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
  ) external view returns (uint256 expectedAmountOut) {
    // Validate inputs
    require(amountIn >= MIN_SWAP_AMOUNT, 'Swap amount too low');
    require(tokenIn != address(0) && tokenOut != address(0), 'Invalid token address');

    // In a real implementation, you'd use Uniswap's QuoterV2 for precise quotes
    // This is a simplified placeholder
    expectedAmountOut = _simulateQuote(tokenIn, tokenOut, amountIn, poolFee);

    // emit QuoteReceived(tokenIn, tokenOut, amountIn, expectedAmountOut);

    return expectedAmountOut;
  }

  /**
   * @dev Simulated quote function (replace with actual quote logic)
   */
  function _simulateQuote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint24 poolFee
  ) internal pure returns (uint256) {
    // Placeholder implementation - in reality, this would interact with Uniswap's quoter
    // This is just a simple example and should NOT be used in production
    return (amountIn * 95) / 100; // Simulates a 5% slippage
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
