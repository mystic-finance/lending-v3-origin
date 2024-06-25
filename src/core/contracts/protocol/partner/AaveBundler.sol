// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import '../../interfaces/IPool.sol';
import '../../interfaces/IPriceOracleGetter.sol';
import '../../interfaces/IPoolAddressesProvider.sol';
import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from 'src/core/contracts/protocol/libraries/configuration/UserConfiguration.sol';

contract AaveBundler {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using SafeERC20 for IERC20;

  constructor() {}

  function checkCollateralSetting(
    IPool pool,
    address onBehalfOf,
    address collateralAsset
  ) public view returns (bool isUsingAsCollateral) {
    DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(onBehalfOf);
    address[] memory reservesList = pool.getReservesList();
    uint256 reserveIndex = 0;
    for (uint i = 0; i < reservesList.length; i++) {
      if (reservesList[i] == collateralAsset) {
        reserveIndex = i;
        break;
      }
    }

    isUsingAsCollateral = userConfig.isUsingAsCollateral(reserveIndex);
  }

  function supply(
    IPoolAddressesProvider addressesProvider,
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external {
    IPool pool = IPool(addressesProvider.getPool());
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(asset).safeApprove(address(pool), amount);
    pool.supply(asset, amount, onBehalfOf, referralCode);
  }

  function withdraw(
    IPoolAddressesProvider addressesProvider,
    address asset,
    uint256 amount,
    address to
  ) external {
    IPool pool = IPool(addressesProvider.getPool());
    pool.withdraw(asset, amount, to);
  }

  function borrow(
    IPoolAddressesProvider addressesProvider,
    address collateralAsset,
    uint256 collateralAmount,
    address borrowAsset,
    uint256 borrowAmount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external {
    IPool pool = IPool(addressesProvider.getPool());

    {
      // Get asset prices
      uint256 collateralPrice = IPriceOracleGetter(addressesProvider.getPriceOracle())
        .getAssetPrice(collateralAsset);
      uint256 borrowPrice = IPriceOracleGetter(addressesProvider.getPriceOracle()).getAssetPrice(
        borrowAsset
      );

      // Get collateral configuration
      (uint256 baseLTV, , , , , ) = pool.getConfiguration(collateralAsset).getParams();

      // Calculate LTV
      uint256 currentLTV = (borrowAmount * borrowPrice * 1e4) /
        (collateralAmount * collateralPrice); // Multiply by 1e4 for percentage calculation

      // Check if LTV is within limits
      require(currentLTV <= baseLTV, 'Borrow amount exceeds allowed LTV');
    }

    // Supply collateral

    IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
    IERC20(collateralAsset).safeApprove(address(pool), collateralAmount);

    pool.supply(collateralAsset, collateralAmount, onBehalfOf, referralCode);

    // Check if the asset is already set as collateral
    require(
      checkCollateralSetting(pool, onBehalfOf, collateralAsset),
      'collateral not set for asset'
    );

    // Borrow
    pool.borrow(borrowAsset, borrowAmount, interestRateMode, referralCode, onBehalfOf);

    // Transfer remaining aTokens to the user
    address aTokenAddress = pool.getReserveData(collateralAsset).aTokenAddress;
    uint256 aTokenBalance = IERC20(aTokenAddress).balanceOf(address(this));
    IERC20(aTokenAddress).safeTransfer(onBehalfOf, aTokenBalance);
    IERC20(borrowAsset).safeTransfer(onBehalfOf, borrowAmount);
  }

  function repay(
    IPoolAddressesProvider addressesProvider,
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external {
    IPool pool = IPool(addressesProvider.getPool());

    // Transfer repayment amount from user to bundler
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

    // Approve Aave pool to spend the repayment amount
    IERC20(asset).safeApprove(address(pool), amount);

    // Repay the loan
    pool.repay(asset, amount, interestRateMode, onBehalfOf);

    // If there's any excess (in case of full repayment), return it to the user
    uint256 remainingBalance = IERC20(asset).balanceOf(address(this));
    if (remainingBalance > 0) {
      IERC20(asset).safeTransfer(msg.sender, remainingBalance);
    }
  }
}
