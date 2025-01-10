// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20Mock as MockERC20} from 'tests/mocks/ERC20Mock.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';

interface IAaveOracle {
  function getAssetPrice(address asset) external view returns (uint256);
}

contract MockSwapController {
  IAaveOracle public immutable aaveOracle;

  constructor(address _pool) {
    aaveOracle = IAaveOracle(IPool(_pool).ADDRESSES_PROVIDER().getPriceOracle());
  }

  function getQuote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint24 poolFee
  ) external view returns (uint256 expectedAmountOut) {
    // Get token prices and decimals
    uint256 tokenInPrice = aaveOracle.getAssetPrice(tokenIn);
    uint256 tokenOutPrice = aaveOracle.getAssetPrice(tokenOut);
    uint256 tokenInDecimals = IERC20Metadata(tokenIn).decimals();
    uint256 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();

    // Calculate USD value of input amount (8 decimals precision from Aave Oracle)
    uint256 inputValueInUsd = (amountIn * tokenInPrice) / 10 ** tokenInDecimals;

    // Apply 0.3% slippage to USD value
    uint256 outputValueInUsd = (inputValueInUsd * (10000 - poolFee - 500)) / 10000;

    // Convert USD value to output token amount
    uint256 amountOut = (outputValueInUsd * 10 ** tokenOutDecimals) / tokenOutPrice;

    return amountOut;
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOutMinimum,
    uint24 poolFee
  ) external returns (uint256) {
    // Get token prices and decimals
    uint256 tokenInPrice = aaveOracle.getAssetPrice(tokenIn);
    uint256 tokenOutPrice = aaveOracle.getAssetPrice(tokenOut);
    uint256 tokenInDecimals = IERC20Metadata(tokenIn).decimals();
    uint256 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();

    // Calculate USD value of input amount (8 decimals precision from Aave Oracle)
    uint256 inputValueInUsd = (amountIn * tokenInPrice) / 10 ** tokenInDecimals;

    // Apply 0.3% slippage to USD value
    uint256 outputValueInUsd = (inputValueInUsd * (10000 - poolFee / 2)) / 10000;

    // Convert USD value to output token amount
    uint256 amountOut = (outputValueInUsd * 10 ** tokenOutDecimals) / tokenOutPrice;

    require(amountOut >= amountOutMinimum, 'Insufficient output amount');

    // Execute transfers
    MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
    MockERC20(tokenOut).transfer(msg.sender, amountOut);

    return amountOut;
  }
}
