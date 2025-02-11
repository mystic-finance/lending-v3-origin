// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "../ILendingProvider.sol";

// /**
//  * @title Compound's CErc20 Interface Contract
//  * @notice CTokens which wrap an EIP-20 underlying
//  * @author Compound
//  */


// interface CTokenInterface {
//     /*** User Interface ***/

//     function transfer(address dst, uint amount) virtual external returns (bool);
//     function transferFrom(address src, address dst, uint amount) virtual external returns (bool);
//     function approve(address spender, uint amount) virtual external returns (bool);
//     function allowance(address owner, address spender) virtual external view returns (uint);
//     function balanceOf(address owner) virtual external view returns (uint);
//     function balanceOfUnderlying(address owner) virtual external returns (uint);
//     function getAccountSnapshot(address account) virtual external view returns (uint, uint, uint, uint);
//     function borrowRatePerBlock() virtual external view returns (uint);
//     function supplyRatePerBlock() virtual external view returns (uint);
//     function totalBorrowsCurrent() virtual external returns (uint);
//     function borrowBalanceCurrent(address account) virtual external returns (uint);
//     function borrowBalanceStored(address account) virtual external view returns (uint);
//     function exchangeRateCurrent() virtual external returns (uint);
//     function exchangeRateStored() virtual external view returns (uint);
//     function getCash() virtual external view returns (uint);
//     function accrueInterest() virtual external returns (uint);
//     function seize(address liquidator, address borrower, uint seizeTokens) virtual external returns (uint);
// }

// interface CErc20 {
//     /*** User Interface ***/

//     function mint(uint mintAmount) virtual external returns (uint);
//     function redeem(uint redeemTokens) virtual external returns (uint);
//     function redeemUnderlying(uint redeemAmount) virtual external returns (uint);
//     function borrow(uint borrowAmount) virtual external returns (uint);
//     function repayBorrow(uint repayAmount) virtual external returns (uint);
//     function repayBorrowBehalf(address borrower, uint repayAmount) virtual external returns (uint);
//     function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) virtual external returns (uint);

//     /*** Admin Functions ***/

//     function _addReserves(uint addAmount) virtual external returns (uint);
// }


// contract CompoundProvider is ILendingProvider, Ownable {
//     mapping(address => address) public cTokens; // Maps underlying assets to their cTokens

//     function setCToken(address underlying, address cToken) external onlyOwner {
//         cTokens[underlying] = cToken;
//     }

//     function supply(address asset, uint256 amount, address, uint16) external override {
//         address cToken = cTokens[asset];
//         require(cToken != address(0), "Compound: cToken not set");
//         require(CErc20(cToken).mint(amount) == 0, "Compound: mint failed");
//     }

//     function borrow(address asset, uint256 amount, uint256, address, uint16) external override {
//         address cToken = cTokens[asset];
//         require(cToken != address(0), "Compound: cToken not set");
//         require(CErc20(cToken).borrow(amount) == 0, "Compound: borrow failed");
//     }

//     function liquidate(address borrower, address debtAsset, address collateralAsset, uint256 repayAmount, bool) external override {
//         address cTokenDebt = cTokens[debtAsset];
//         address cTokenCollateral = cTokens[collateralAsset];
//         require(cTokenDebt != address(0) && cTokenCollateral != address(0), "Compound: cToken not set");
//         require(CErc20(cTokenDebt).liquidateBorrow(borrower, repayAmount, CTokenInterface(cTokenCollateral)) == 0, "Compound: liquidation failed");
//     }

//     function getLiquidateableUsers() external view override returns (address[] memory users, uint256[] memory repayAmounts) {
//         // Compound does not provide an on-chain function to fetch liquidatable users.
//         // This data is typically computed off-chain using Compound's subgraph or risk models.
//         users = new address[](0);
//         repayAmounts = new uint256[](0);
//     }
// }