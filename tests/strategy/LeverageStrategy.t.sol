// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import 'forge-std/Test.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// import {LeveragedBorrowingVault} from 'src/LeveragedBorrowingVault.sol';
// import {MockERC20} from './mocks/MockERC20.sol';
// import {MockLendingPool} from './mocks/MockLendingPool.sol';
// import {MockSwapController} from './mocks/MockSwapController.sol';
// import {MockFlashLoanController} from './mocks/MockFlashLoanController.sol';

// contract LeveragedBorrowingVaultTest is Test {
//     // Test Addresses
//     address internal immutable deployer;
//     address internal immutable user;
//     address internal immutable anotherUser;

//     // Contract instances
//     LeveragedBorrowingVault internal vault;
//     MockERC20 internal collateralToken;
//     MockERC20 internal borrowToken;
//     MockLendingPool internal lendingPool;
//     MockSwapController internal swapController;
//     MockFlashLoanController internal flashLoanController;

//     // Constants for testing
//     uint256 internal constant INITIAL_BALANCE = 100_000 * 10**18;
//     uint256 internal constant INITIAL_COLLATERAL = 10_000 * 10**18;
//     uint256 internal constant LEVERAGE_MULTIPLIER = 3;

//     constructor() {
//         deployer = makeAddr('DEPLOYER');
//         user = makeAddr('USER');
//         anotherUser = makeAddr('ANOTHER_USER');
//     }

//     function setUp() public {
//         vm.startPrank(deployer);

//         // Deploy mock tokens
//         collateralToken = new MockERC20('CollateralToken', 'CLT', 18);
//         borrowToken = new MockERC20('BorrowToken', 'BRT', 18);

//         // Deploy mock controllers
//         lendingPool = new MockLendingPool();
//         swapController = new MockSwapController();
//         flashLoanController = new MockFlashLoanController();

//         // Deploy the vault
//         vault = new LeveragedBorrowingVault(
//             address(lendingPool),
//             address(swapController),
//             address(flashLoanController)
//         );

//         // Add tokens as allowed
//         vault.addAllowedCollateralToken(address(collateralToken));
//         vault.addAllowedBorrowToken(address(borrowToken));

//         // Mint tokens to user
//         collateralToken.mint(user, INITIAL_BALANCE);
//         borrowToken.mint(user, INITIAL_BALANCE);

//         vm.stopPrank();
//     }

//     // Test helper to prepare user tokens and approvals
//     function _prepareUserTokens(address _user) internal {
//         vm.startPrank(_user);
//         collateralToken.approve(address(vault), INITIAL_COLLATERAL);
//         vm.stopPrank();
//     }

//     // Test: Successful leverage position opening
//     function test_openLeveragePosition_Success() public {
//         _prepareUserTokens(user);

//         vm.startPrank(user);
//         vm.expectEmit(true, false, false, true);
//         emit LeveragePositionOpened(
//             user,
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );
//         vm.stopPrank();

//         // Validate user position
//         (
//             address positionUser,
//             address positionCollateralToken,
//             address positionBorrowToken,
//             uint256 initialCollateral,
//             uint256 totalCollateral,
//             uint256 totalBorrowed,
//             uint256 leverageMultiplier,
//             bool isActive
//         ) = vault.userPositions(user);

//         assertEq(positionUser, user);
//         assertEq(positionCollateralToken, address(collateralToken));
//         assertEq(positionBorrowToken, address(borrowToken));
//         assertEq(initialCollateral, INITIAL_COLLATERAL);
//         assertTrue(isActive);
//     }

//     // Test: Revert on invalid leverage multiplier
//     function test_openLeveragePosition_RevertOn_InvalidLeverage() public {
//         _prepareUserTokens(user);

//         vm.startPrank(user);
//         vm.expectRevert('Invalid leverage');
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             0  // Invalid leverage
//         );

//         vm.expectRevert('Invalid leverage');
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             21  // Exceeds max leverage
//         );
//         vm.stopPrank();
//     }

//     // Test: Revert on non-allowed tokens
//     function test_openLeveragePosition_RevertOn_DisallowedTokens() public {
//         MockERC20 unknownToken = new MockERC20('UnknownToken', 'UNK', 18);
//         _prepareUserTokens(user);

//         vm.startPrank(user);
//         vm.expectRevert('Collateral token not allowed');
//         vault.openLeveragePosition(
//             address(unknownToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );

//         vm.expectRevert('Borrow token not allowed');
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(unknownToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );
//         vm.stopPrank();
//     }

//     // Test: Closing leverage position
//     function test_closeLeveragePosition_Success() public {
//         // First, open a position
//         _prepareUserTokens(user);
//         vm.prank(user);
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );

//         // Simulate good health factor
//         lendingPool.setHealthFactor(2);  // Healthy position

//         // Close position
//         vm.startPrank(user);
//         vm.expectEmit(true, false, false, true);
//         emit LeveragePositionClosed(user, INITIAL_COLLATERAL);
//         vault.closeLeveragePosition();
//         vm.stopPrank();

//         // Verify position is closed
//         (, , , , , , , bool isActive) = vault.userPositions(user);
//         assertFalse(isActive);
//     }

//     // Test: Revert closing position with low health factor
//     function test_closeLeveragePosition_RevertOn_LowHealthFactor() public {
//         // Open position
//         _prepareUserTokens(user);
//         vm.prank(user);
//         vault.openLeveragePosition(
//             address(collateralToken),
//             address(borrowToken),
//             INITIAL_COLLATERAL,
//             LEVERAGE_MULTIPLIER
//         );

//         // Simulate low health factor
//         lendingPool.setHealthFactor(0.5);

//         // Try to close position
//         vm.startPrank(user);
//         vm.expectRevert('Position health is too low');
//         vault.closeLeveragePosition();
//         vm.stopPrank();
//     }

//     // Test: Admin token management
//     function test_adminTokenManagement() public {
//         vm.startPrank(deployer);

//         MockERC20 newToken = new MockERC20('NewToken', 'NEW', 18);

//         // Add token
//         vault.addAllowedCollateralToken(address(newToken));
//         assertTrue(vault.allowedCollateralTokens(address(newToken)));

//         // Remove token
//         vault.removeAllowedCollateralToken(address(newToken));
//         assertFalse(vault.allowedCollateralTokens(address(newToken)));

//         vm.stopPrank();
//     }

//     // Revert on non-owner token management
//     function test_revertOn_UnauthorizedTokenManagement() public {
//         MockERC20 newToken = new MockERC20('NewToken', 'NEW', 18);

//         vm.startPrank(user);
//         vm.expectRevert();
//         vault.addAllowedCollateralToken(address(newToken));

//         vm.expectRevert();
//         vault.removeAllowedCollateralToken(address(newToken));
//         vm.stopPrank();
//     }
// }
