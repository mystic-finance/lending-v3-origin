// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.10;

// import '../../dependencies/openzeppelin/contracts/IERC20.sol';
// import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
// import '../../interfaces/IPool.sol';
// import '../../interfaces/IPriceOracleGetter.sol';
// import '../../interfaces/IPoolAddressesProvider.sol';
// import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
// import {UserConfiguration} from 'src/core/contracts/protocol/libraries/configuration/UserConfiguration.sol';

// contract AaveBundler {
//   using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
//   using UserConfiguration for DataTypes.UserConfigurationMap;
//   using SafeERC20 for IERC20;

//   mapping(address => uint256) public borrows; // Amount borrowed by user
//   mapping(address => uint256) public collateral; // Amount of collateral held for each user

//   constructor() {}

//   function checkCollateralSetting(
//     IPool pool,
//     address onBehalfOf,
//     address collateralAsset
//   ) public view returns (bool isUsingAsCollateral) {
//     DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(onBehalfOf);
//     address[] memory reservesList = pool.getReservesList();
//     uint256 reserveIndex = 0;
//     for (uint i = 0; i < reservesList.length; i++) {
//       if (reservesList[i] == collateralAsset) {
//         reserveIndex = i;
//         break;
//       }
//     }

//     isUsingAsCollateral = userConfig.isUsingAsCollateral(reserveIndex);
//   }

//   function supply(
//     IPoolAddressesProvider addressesProvider,
//     address asset,
//     uint256 amount,
//     address onBehalfOf,
//     uint16 referralCode
//   ) external {
//     IPool pool = IPool(addressesProvider.getPool());
//     IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
//     IERC20(asset).safeApprove(address(pool), amount);
//     pool.supply(asset, amount, onBehalfOf, referralCode);
//   }

//   function withdraw(
//     IPoolAddressesProvider addressesProvider,
//     address asset,
//     uint256 amount,
//     address to
//   ) external {
//     IPool pool = IPool(addressesProvider.getPool());
//     pool.withdraw(asset, amount, to);
//   }

//   function borrow(
//     IPoolAddressesProvider addressesProvider,
//     address collateralAsset,
//     uint256 collateralAmount,
//     address borrowAsset,
//     uint256 borrowAmount,
//     uint256 interestRateMode,
//     uint16 referralCode
//   ) external {
//     IPool pool = IPool(addressesProvider.getPool());
//     borrows[msg.sender] += borrowAmount; // Track borrowed amount
//     collateral[msg.sender] += collateralAmount;

//     // Hold collateral
//     IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
//     IERC20(collateralAsset).safeApprove(address(pool), collateralAmount);

//     // supply collateral as owner of the asset
//     pool.supply(collateralAsset, collateralAmount, msg.sender, referralCode);
//     pool.setUserUseReserveAsCollateral(collateralAsset, true);

//     // Check if the asset is already set as collateral
//     require(
//       checkCollateralSetting(pool, onBehalfOf, collateralAsset),
//       'collateral not set for asset'
//     );

//     // Calculate the current health factor
//     uint256 currentHealthFactor = calculateHealthFactor(pool, msg.sender);
//     require(currentHealthFactor >= 1, 'Health factor must remain above 1');

//     // Borrow
//     pool.borrow(borrowAsset, borrowAmount, interestRateMode, referralCode, msg.sender);

//     // Transfer remaining aTokens to the user
//     IERC20(borrowAsset).safeTransfer(msg.sender, borrowAmount);
//   }

//   function repay(
//     IPoolAddressesProvider addressesProvider,
//     address asset,
//     uint256 amount,
//     uint256 interestRateMode
//   ) external {
//     IPool pool = IPool(addressesProvider.getPool());

//     // Transfer repayment amount from user to bundler
//     IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

//     // Approve Aave pool to spend the repayment amount
//     IERC20(asset).safeApprove(address(pool), amount);

//     // Repay the loan
//     pool.repay(asset, amount, interestRateMode, msg.sender);

//     // Update the user's borrowed amount
//     borrows[msg.sender] -= amount;

//     // If there's any excess (in case of full repayment), return it to the user
//     uint256 remainingBalance = IERC20(asset).balanceOf(address(this));
//     if (remainingBalance > 0) {
//       IERC20(asset).safeTransfer(msg.sender, remainingBalance);
//     }
//   }

//   function withdrawCollateral(
//     IPoolAddressesProvider addressesProvider,
//     address collateralAsset,
//     uint256 amount
//   ) external {
//     require(collateral[msg.sender] >= amount, 'Insufficient collateral to withdraw');

//     // Withdraw collateral from the pool
//     pool.withdraw(collateralAsset, amount, address(this));

//     // Update the collateral tracking
//     collateral[msg.sender] -= amount;

//     // Calculate the current health factor
//     uint256 currentHealthFactor = calculateHealthFactor(pool, msg.sender);
//     require(currentHealthFactor >= 1, 'Health factor must remain above 1');

//     // Transfer the collateral back to the user
//     IERC20(collateralAsset).safeTransfer(msg.sender, amount);
//   }

//   function calculateHealthFactor(IPool pool, address user) internal view returns (uint256) {
//     // Implement the logic to calculate the health factor based on the user's collateral and debt
//     // This is a placeholder; you will need to fetch the user's collateral and debt values from the pool
//     // and calculate the health factor accordingly.
//     // Example:
//     uint256 totalCollateralValue = collateral[user]; // Calculate total collateral value
//     uint256 totalDebtValue = borrows[user]; // Get total debt value

//     // Assuming a simple calculation for demonstration purposes
//     if (totalDebtValue == 0) return type(uint256).max; // No debt means infinite health factor

//     // Health factor calculation
//     // intentionally made to be higher than conventional hf of collateralValue * liqThreshold/DebtValue (since liqThreshold is in range 0.8 - 0.95)
//     // we want hf to be conventionally higher than pool hf to avoid loss through liquidation from the pool
//     return totalCollateralValue / totalDebtValue;
//   }

//   function liquidate(address user, uint256 collateralAmount, uint256 debtAmount) external {
//     IPool pool = IPool(addressesProvider.getPool());

//     // Check the user's health factor
//     uint256 healthFactor = calculateHealthFactor(pool, user);
//     require(healthFactor < 1, 'Health factor is above threshold, no liquidation needed');

//     // Get asset prices
//     uint256 collateralPrice = IPriceOracleGetter(addressesProvider.getPriceOracle()).getAssetPrice(
//       collateralAsset
//     );
//     uint256 borrowPrice = IPriceOracleGetter(addressesProvider.getPriceOracle()).getAssetPrice(
//       borrowAsset
//     );

//     // threoreticallydebtAMount should be whole Debt
//     require(
//       collateralAmount * collateralPrice <= debtAmount * borrowPrice,
//       'Amount value must match for accouting'
//     );

//     // Repay the debt
//     IERC20(borrowAsset).safeTransferFrom(msg.sender, address(this), debtAmount);
//     IERC20(borrowAsset).safeApprove(address(pool), debtAmount);
//     pool.repay(borrowAsset, debtAmount, interestRateMode, user);

//     // Withdraw collateral from the pool
//     pool.withdraw(collateralAsset, collateralAmount, address(this));

//     // Check the user's health factor
//     uint256 newHealthFactor = calculateHealthFactor(pool, user);
//     require(newHealthFactor > 1, 'Health factor is below threshold, liquidation is not successful');

//     // Update the user's collateral and borrows
//     collateral[user] -= collateralAmount;
//     borrows[user] -= debtAmount;

//     // Transfer the collateral back to the liquidator
//     IERC20(collateralAsset).safeTransfer(msg.sender, amount);
//     emit Liquidation(user, collateralAmount, debtAmount);
//   }
// }
