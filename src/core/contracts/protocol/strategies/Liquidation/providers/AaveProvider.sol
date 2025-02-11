// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "../ILendingProvider.sol";
// import "src/core/contracts/interfaces/IPool.sol";

// contract AaveProvider is ILendingProvider, Ownable {
//     IPool public immutable aavePool;

//     constructor(address _aavePool) {
//         aavePool = IPool(_aavePool);
//     }

//     function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {
//         aavePool.supply(asset, amount, onBehalfOf, referralCode);
//     }

//     function borrow(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf, uint16 referralCode) external override {
//         aavePool.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
//     }

//     function liquidate(address borrower, address debtAsset, address collateralAsset, uint256 repayAmount, bool receiveAToken) external override {
//         aavePool.liquidationCall(collateralAsset, debtAsset, borrower, repayAmount, receiveAToken);
//     }

//     function getLiquidateableUsers() external view override returns (address[] memory users, uint256[] memory repayAmounts) {
//         // Aave does not provide an on-chain function to fetch liquidatable users.
//         // This data is typically computed off-chain using Aave's subgraph or risk models.
//         users = new address[](0);
//         repayAmounts = new uint256[](0);
//     }
// }