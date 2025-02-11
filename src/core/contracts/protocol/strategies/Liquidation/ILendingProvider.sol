// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILendingProvider {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf, uint16 referralCode) external;
    function liquidate(address borrower, address debtAsset, address collateralAsset, uint256 repayAmount, bool receiveAToken) external;
    function getLiquidateableUsers() external view returns (address[] memory users, uint256[] memory repayAmounts);
}