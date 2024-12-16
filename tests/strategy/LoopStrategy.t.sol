// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import 'forge-std/Test.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import {AdvancedLoopStrategy} from 'src/AdvancedLoopStrategy.sol';
// import {ERC20Mock} from './mocks/ERC20Mock.sol';
// import {MockLendingPool} from './mocks/MockLendingPool.sol';
// import {MockSwapController} from './mocks/MockSwapController.sol';
// import {MockAaveOracle} from './mocks/MockAaveOracle.sol';

// contract AdvancedLoopStrategyTest is Test {
//   // Contract instances
//   AdvancedLoopStrategy public strategy;
//   ERC20Mock public collateralToken;
//   ERC20Mock public borrowToken;
//   MockLendingPool public mockLendingPool;
//   MockSwapController public mockSwapController;
//   MockAaveOracle public mockPriceOracle;

//   // Test addresses
//   address public owner;
//   address public bob;

//   // Constants for testing
//   uint256 constant INITIAL_BALANCE = 1000e18;
//   uint256 constant INITIAL_COLLATERAL = 100e18;
//   uint24 constant POOL_FEE = 3000; // 0.3%

//   function setUp() public {
//     // Setup test addresses
//     owner = address(this);
//     bob = address(0x1);

//     // Deploy mock tokens
//     collateralToken = new ERC20Mock('Collateral', 'COL', 18);
//     borrowToken = new ERC20Mock('Borrow', 'BOR', 18);

//     // Deploy mock protocols
//     mockLendingPool = new MockLendingPool();
//     mockSwapController = new MockSwapController();
//     mockPriceOracle = new MockAaveOracle();

//     // Set up initial token balances
//     collateralToken.mint(owner, INITIAL_BALANCE);
//     borrowToken.mint(owner, INITIAL_BALANCE);
//     collateralToken.mint(bob, INITIAL_BALANCE);
//     borrowToken.mint(bob, INITIAL_BALANCE);

//     // Deploy strategy
//     strategy = new AdvancedLoopStrategy(
//       owner,
//       address(mockLendingPool),
//       address(mockSwapController),
//       POOL_FEE
//     );

//     // Prepare mock price
//     mockPriceOracle.setAssetPrice(address(borrowToken), 1e18);

//     // Approve strategy to spend tokens
//     collateralToken.approve(address(strategy), type(uint256).max);
//     borrowToken.approve(address(strategy), type(uint256).max);
//   }

//   function testConstructor() public {
//     assertEq(
//       address(strategy.lendingPool()),
//       address(mockLendingPool),
//       'Lending pool address incorrect'
//     );
//     assertEq(
//       address(strategy.swapController()),
//       address(mockSwapController),
//       'Swap controller address incorrect'
//     );
//     assertEq(strategy.targetLeverageMultiplier(), 1, 'Default leverage should be 1');
//   }

//   function testEnterPosition() public {
//     // Set up mock lending pool and swap controller behaviors
//     mockLendingPool.setUserAccountData(
//       10e18, // totalCollateralETH
//       0, // totalDebtETH
//       5e18, // availableBorrowsETH
//       7000, // liquidationThreshold
//       6000, // ltv
//       2 // healthFactor
//     );
//     mockSwapController.setExpectedSwapOutput(INITIAL_COLLATERAL / 2);

//     // Prepare for entering position
//     uint256 iterations = 2;

//     // Enter position
//     vm.prank(owner);
//     strategy.enterPosition(
//       address(collateralToken),
//       address(borrowToken),
//       address(mockPriceOracle),
//       INITIAL_COLLATERAL,
//       iterations
//     );

//     // Assertions
//     assertEq(
//       collateralToken.balanceOf(address(strategy)),
//       0,
//       'Strategy should not hold collateral tokens'
//     );
//   }

//   function testExitPosition() public {
//     // First enter a position
//     testEnterPosition();

//     // Set up mock lending pool and swap controller for exit
//     mockLendingPool.setUserAccountData(
//       10e18, // totalCollateralETH
//       5e18, // totalDebtETH
//       0, // availableBorrowsETH
//       7000, // liquidationThreshold
//       6000, // ltv
//       2 // healthFactor
//     );
//     mockSwapController.setExpectedSwapOutput(INITIAL_COLLATERAL / 2);

//     // Exit position
//     vm.prank(owner);
//     uint256 withdrawnAmount = strategy.exitPosition(
//       address(collateralToken),
//       address(borrowToken),
//       address(mockPriceOracle)
//     );

//     // Assertions
//     assertTrue(withdrawnAmount > 0, 'Should withdraw some amount');
//     assertEq(
//       collateralToken.balanceOf(owner),
//       withdrawnAmount,
//       'Owner should receive withdrawn amount'
//     );
//   }

//   function testUpdateLeverageParameters() public {
//     uint256 newLeverageMultiplier = 3;
//     uint256 newMaxIterations = 10;

//     vm.prank(owner);
//     strategy.updateLeverageParameters(newLeverageMultiplier, newMaxIterations);

//     assertEq(
//       strategy.targetLeverageMultiplier(),
//       newLeverageMultiplier,
//       'Leverage multiplier not updated'
//     );
//     assertEq(strategy.maxIterations(), newMaxIterations, 'Max iterations not updated');
//   }

//   function testUpdateSwapController() public {
//     MockSwapController newSwapController = new MockSwapController();

//     vm.prank(owner);
//     strategy.updateSwapController(address(newSwapController));

//     assertEq(
//       address(strategy.swapController()),
//       address(newSwapController),
//       'Swap controller not updated'
//     );
//   }

//   function testCalculateMaxSafeIterations() public {
//     // Set up mock lending pool configuration
//     mockLendingPool.setReserveConfiguration(address(collateralToken), 7000); // 70% LTV

//     uint256 maxIterations = strategy.calculateMaxSafeIterations(address(collateralToken));

//     assertTrue(maxIterations > 0, 'Should calculate safe iterations');
//     assertTrue(maxIterations <= strategy.maxIterations(), 'Should not exceed max iterations');
//   }

//   function testOnlyOwnerRestrictions() public {
//     vm.startPrank(bob);

//     // Test enter position
//     vm.expectRevert(bytes('Ownable: caller is not the owner'));
//     strategy.enterPosition(
//       address(collateralToken),
//       address(borrowToken),
//       address(mockPriceOracle),
//       INITIAL_COLLATERAL,
//       2
//     );

//     // Test exit position
//     vm.expectRevert(bytes('Ownable: caller is not the owner'));
//     strategy.exitPosition(address(collateralToken), address(borrowToken), address(mockPriceOracle));

//     // Test update leverage parameters
//     vm.expectRevert(bytes('Ownable: caller is not the owner'));
//     strategy.updateLeverageParameters(3, 10);

//     // Test update swap controller
//     vm.expectRevert(bytes('Ownable: caller is not the owner'));
//     strategy.updateSwapController(address(0x123));

//     vm.stopPrank();
//   }

//   // Revert tests
//   function testRevertInvalidParameters() public {
//     // Test invalid leverage multiplier
//     vm.prank(owner);
//     vm.expectRevert(bytes('Invalid leverage'));
//     strategy.updateLeverageParameters(0, 10);

//     // Test invalid swap controller
//     vm.prank(owner);
//     vm.expectRevert(bytes('Invalid swap controller'));
//     strategy.updateSwapController(address(0));
//   }
// }

// // Mock Contracts for Testing
// contract MockLendingPool {
//   struct ReserveConfigurationMap {
//     uint256 data;
//   }

//   ReserveConfigurationMap public reserveConfiguration;
//   uint256 public userAccountData;

//   function setReserveConfiguration(address asset, uint256 ltv) external {
//     reserveConfiguration.data = ltv << 16;
//   }

//   function getConfiguration(address) external view returns (ReserveConfigurationMap memory) {
//     return reserveConfiguration;
//   }

//   function setUserAccountData(
//     uint256 totalCollateralETH,
//     uint256 totalDebtETH,
//     uint256 availableBorrowsETH,
//     uint256 currentLiquidationThreshold,
//     uint256 ltv,
//     uint256 healthFactor
//   ) external {
//     userAccountData =
//       (totalCollateralETH << 160) |
//       (totalDebtETH << 96) |
//       (availableBorrowsETH << 32) |
//       (currentLiquidationThreshold << 16) |
//       ltv;
//   }

//   function getUserAccountData(
//     address
//   )
//     external
//     view
//     returns (
//       uint256 totalCollateralETH,
//       uint256 totalDebtETH,
//       uint256 availableBorrowsETH,
//       uint256 currentLiquidationThreshold,
//       uint256 ltv,
//       uint256 healthFactor
//     )
//   {
//     return (
//       (userAccountData >> 160) & type(uint256).max,
//       (userAccountData >> 96) & type(uint256).max,
//       (userAccountData >> 32) & type(uint256).max,
//       (userAccountData >> 16) & 0xffff,
//       userAccountData & 0xffff,
//       2
//     );
//   }

//   function deposit(address, uint256, address, uint16) external {}
//   function borrow(address, uint256, uint256, uint16, address) external {}
//   function withdraw(address, uint256, address) external returns (uint256) {
//     return 0;
//   }
//   function repay(address, uint256, uint256, address) external returns (uint256) {
//     return 0;
//   }
// }

// contract MockSwapController {
//   uint256 public expectedOutput;

//   function setExpectedSwapOutput(uint256 _output) external {
//     expectedOutput = _output;
//   }

//   function swap(address, address, uint256, uint256, uint24) external returns (uint256) {
//     return expectedOutput;
//   }

//   function getQuote(address, address, uint256, uint24) external view returns (uint256) {
//     return expectedOutput;
//   }
// }

// contract MockAaveOracle {
//   mapping(address => uint256) public assetPrices;

//   function setAssetPrice(address asset, uint256 price) external {
//     assetPrices[asset] = price;
//   }

//   function getAssetPrice(address asset) external view returns (uint256) {
//     return assetPrices[asset];
//   }
// }
