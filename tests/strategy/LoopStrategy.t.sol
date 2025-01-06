// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {AdvancedLoopStrategy} from 'src/core/contracts/protocol/strategies/LoopStrategy.sol';
import {ERC20Mock as MockERC20} from 'tests/mocks/ERC20Mock.sol';
import '../../src/core/contracts/interfaces/IPool.sol';
import {FlashLoanController} from 'src/core/contracts/protocol/strategies/FlashLoanController.sol';
import {IAaveOracle} from 'src/core/contracts/interfaces/IAaveOracle.sol';
import {MockSwapController} from 'tests/mocks/SwapController.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {ICreditDelegationToken} from 'src/core/contracts/interfaces/ICreditDelegationToken.sol';

contract AdvancedLoopStrategyTest is TestnetProcedures {
  // Contract instances
  AdvancedLoopStrategy public strategy;
  MockERC20 public collateralToken;
  MockERC20 public borrowToken;
  IPool public mockLendingPool;
  MockSwapController public mockSwapController;
  IAaveOracle public mockPriceOracle;

  // Test addresses
  address public owner;
  // address public bob;

  // Constants for testing
  uint256 constant INITIAL_BALANCE = 1000e18;
  uint256 constant INITIAL_COLLATERAL = 1e18;
  uint24 constant POOL_FEE = 30; // 0.3%

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    bob = address(0x100);
    vm.startPrank(owner);

    // Deploy mock tokens
    collateralToken = MockERC20(address(wbtc)); //new MockERC20('CollateralToken', 'CLT', 18);
    borrowToken = MockERC20(address(usdx)); //new MockERC20('BorrowToken', 'BRT', 18);

    // Deploy mock controllers
    mockLendingPool = IPool(address(contracts.poolProxy));
    mockSwapController = new MockSwapController(address(contracts.poolProxy));
    mockPriceOracle = IAaveOracle(mockLendingPool.ADDRESSES_PROVIDER().getPriceOracle());

    // Set up initial token balances
    vm.startPrank(poolAdmin);
    // deal(address(collateralToken), bob, INITIAL_BALANCE);
    borrowToken.mint(bob, INITIAL_BALANCE);
    collateralToken.mint(bob, INITIAL_COLLATERAL);

    // deal(address(collateralToken), owner, INITIAL_BALANCE * 2);
    borrowToken.mint(owner, INITIAL_BALANCE * 2000_000);
    collateralToken.mint(owner, INITIAL_BALANCE * 2000_000);

    // deal(address(collateralToken), address(mockSwapController), INITIAL_BALANCE * 10000);
    borrowToken.mint(address(mockSwapController), INITIAL_BALANCE * 10000);
    collateralToken.mint(address(mockSwapController), INITIAL_BALANCE * 10000);
    // mockSwapController

    // Deploy strategy
    strategy = new AdvancedLoopStrategy(
      owner,
      address(mockLendingPool),
      address(mockSwapController),
      POOL_FEE
    );

    // Approve strategy to spend tokens
    vm.startPrank(bob);
    collateralToken.approve(address(strategy), type(uint256).max);
    borrowToken.approve(address(strategy), type(uint256).max);

    vm.startPrank(owner);
    collateralToken.approve(address(mockLendingPool), type(uint256).max);
    borrowToken.approve(address(mockLendingPool), type(uint256).max);

    mockLendingPool.supply(address(borrowToken), (INITIAL_BALANCE * 1000_000 * 19) / 20, owner, 0);
    mockLendingPool.supply(
      address(collateralToken),
      (INITIAL_BALANCE * 1000_000 * 19) / 20,
      owner,
      0
    );
  }

  function testEnterPosition() public {
    // Prepare for entering position
    uint256 iterations = 4;

    // Enter position
    vm.startPrank(bob);

    DataTypes.ReserveDataLegacy memory reserveData = mockLendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory reserveData2 = mockLendingPool.getReserveData(
      address(borrowToken)
    );
    IERC20(reserveData.aTokenAddress).approve(address(strategy), INITIAL_COLLATERAL * 1000_000);
    ICreditDelegationToken(reserveData2.variableDebtTokenAddress).approveDelegation(
      address(strategy),
      INITIAL_COLLATERAL * 1000_000
    );
    // mockLendingPool.supply(address(collateralToken), 0.1e18, bob, 0);
    // mockLendingPool.setUserUseReserveAsCollateral(address(collateralToken), true);

    strategy.enterPosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      iterations
    );

    // Assertions
    assertEq(
      collateralToken.balanceOf(address(strategy)),
      0,
      'Strategy should not hold collateral tokens'
    );
  }

  function testExitPosition() public {
    // First enter a position
    testEnterPosition();

    // Exit position
    vm.startPrank(bob);
    uint256[] memory positions = strategy.getUserPositions(bob);
    strategy.exitPosition(positions[0]);
  }

  function testRevertDoubleExitPosition() public {
    // First enter a position
    testEnterPosition();

    // Exit position
    vm.startPrank(bob);
    uint256[] memory positions = strategy.getUserPositions(bob);
    strategy.exitPosition(positions[0]);

    vm.expectRevert(bytes('Position not active'));
    strategy.exitPosition(positions[0]);
  }

  function testUpdateLeverageParameters() public {
    uint256 newLeverageMultiplier = 3;
    uint256 newMaxIterations = 10;

    vm.startPrank(owner);
    strategy.updateLeverageParameters(newLeverageMultiplier, newMaxIterations);

    assertEq(
      strategy.targetLeverageMultiplier(),
      newLeverageMultiplier,
      'Leverage multiplier not updated'
    );
    assertEq(strategy.maxIterations(), newMaxIterations, 'Max iterations not updated');
  }

  function testCalculateMaxSafeIterations() public {
    vm.startPrank(bob);
    uint256 maxIterations = strategy.calculateMaxSafeIterations(
      address(collateralToken),
      address(borrowToken)
    );

    assertTrue(maxIterations > 0, 'Should calculate safe iterations');
    assertTrue(maxIterations <= strategy.maxIterations(), 'Should not exceed max iterations');
  }

  // Revert tests
  function testRevertInvalidParameters() public {
    // Test invalid leverage multiplier
    vm.startPrank(owner);
    vm.expectRevert(bytes('Invalid leverage'));
    strategy.updateLeverageParameters(0, 10);

    // Test invalid swap controller
    vm.startPrank(owner);
    vm.expectRevert(bytes('Invalid swap controller'));
    strategy.updateSwapController(address(0));
  }

  function testEnterPositionWithCorrectAmounts() public {
    uint256 initialCollateral = 1e18;
    uint256 iterations = 4;

    vm.startPrank(bob);

    // Record initial balances
    uint256 initialBobCollateral = collateralToken.balanceOf(bob);

    // Setup approvals
    DataTypes.ReserveDataLegacy memory reserveData = mockLendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory borrowData = mockLendingPool.getReserveData(
      address(borrowToken)
    );
    IERC20(reserveData.aTokenAddress).approve(address(strategy), initialCollateral * 1000_000);
    ICreditDelegationToken(borrowData.variableDebtTokenAddress).approveDelegation(
      address(strategy),
      initialCollateral * 1000_000
    );

    strategy.enterPosition(
      address(collateralToken),
      address(borrowToken),
      initialCollateral,
      iterations
    );

    // Check balances after entering position
    uint256 finalBobCollateral = collateralToken.balanceOf(bob);
    uint256 strategyCollateral = collateralToken.balanceOf(address(strategy));
    uint256 aTokenBalance = IERC20(reserveData.aTokenAddress).balanceOf(bob);
    uint256 debtBalance = IERC20(borrowData.variableDebtTokenAddress).balanceOf(bob);

    assertEq(
      finalBobCollateral,
      initialBobCollateral - initialCollateral,
      'Incorrect collateral deduction'
    );
    assertEq(strategyCollateral, 0, 'Strategy should not hold tokens');
    assertTrue(
      aTokenBalance >= initialCollateral * (iterations - 1),
      'Should have more aTokens than initial deposit'
    );
    assertGt(
      aTokenBalance,
      initialCollateral * (iterations - 1),
      'Incorrect final balance after closing'
    );
    assertGt(debtBalance, initialCollateral * (iterations - 2), 'Should have debt position');
    assertTrue(debtBalance > 0, 'Should have debt position');
  }

  function testExitPositionFullRepayment() public {
    // First enter position
    uint256 initialCollateral = 1e18;
    uint256 iterations = 4;

    vm.startPrank(bob);

    // Setup for entry
    DataTypes.ReserveDataLegacy memory reserveData = mockLendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory borrowData = mockLendingPool.getReserveData(
      address(borrowToken)
    );
    IERC20(reserveData.aTokenAddress).approve(address(strategy), initialCollateral * 1000_000);
    ICreditDelegationToken(borrowData.variableDebtTokenAddress).approveDelegation(
      address(strategy),
      initialCollateral * 1000_000
    );

    // Enter position and record balances
    strategy.enterPosition(
      address(collateralToken),
      address(borrowToken),
      initialCollateral,
      iterations
    );
    uint256 debtBeforeExit = IERC20(borrowData.variableDebtTokenAddress).balanceOf(bob);
    uint256 aTokenBeforeExit = IERC20(reserveData.aTokenAddress).balanceOf(bob);
    uint256 userInitialCollateralBalance = collateralToken.balanceOf(bob);

    // Exit position
    uint256[] memory positions = strategy.getUserPositions(bob);
    strategy.exitPosition(positions[0]);

    // Check final state
    uint256 finalDebt = IERC20(borrowData.variableDebtTokenAddress).balanceOf(bob);
    uint256 finalATokens = IERC20(reserveData.aTokenAddress).balanceOf(bob);
    uint256 finalCollateral = collateralToken.balanceOf(bob);
    uint256 stratCollateral = collateralToken.balanceOf(address(strategy));
    uint256 stratAsset = borrowToken.balanceOf(address(strategy));

    assertEq(finalDebt, 0, 'Should have no remaining debt');
    assertTrue(finalATokens < aTokenBeforeExit, 'Should have less aTokens after exit');
    assertTrue(stratCollateral <= 0, 'no collateral asset should remain in strategy');
    assertTrue(stratAsset <= 0, 'no borrow asset should remain in strategy');

    assertGt(
      finalCollateral,
      userInitialCollateralBalance + initialCollateral - 0.025e18,
      'Incorrect final balance after closing'
    );
  }

  // function testPartialExitPosition() public {
  //   // Enter position first
  //   testEnterPosition();

  //   vm.startPrank(bob);
  //   DataTypes.ReserveDataLegacy memory reserveData = mockLendingPool.getReserveData(
  //     address(collateralToken)
  //   );
  //   uint256 aTokenBeforeExit = IERC20(reserveData.aTokenAddress).balanceOf(bob);

  //   // Try partial exit with half the position
  //   IERC20(reserveData.aTokenAddress).approve(address(strategy), aTokenBeforeExit / 2);
  //   strategy.exitPosition(address(collateralToken), address(borrowToken));

  //   uint256 aTokenAfterExit = IERC20(reserveData.aTokenAddress).balanceOf(bob);
  //   assertLt(aTokenAfterExit, aTokenBeforeExit, 'aToken balance should decrease');
  // }

  function testMaximumLeveragePosition() public {
    vm.startPrank(bob);
    uint256 maxIterations = strategy.calculateMaxSafeIterations(
      address(collateralToken),
      address(borrowToken)
    );
    DataTypes.ReserveDataLegacy memory reserveData = mockLendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory borrowData = mockLendingPool.getReserveData(
      address(borrowToken)
    );
    IERC20(reserveData.aTokenAddress).approve(address(strategy), INITIAL_COLLATERAL * 1000_000);
    ICreditDelegationToken(borrowData.variableDebtTokenAddress).approveDelegation(
      address(strategy),
      INITIAL_COLLATERAL * 1000_000
    );

    strategy.enterPosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      maxIterations
    );

    (, , , , , uint256 healthFactor) = mockLendingPool.getUserAccountData(bob);
    assertTrue(
      healthFactor >= strategy.MIN_HEALTH_FACTOR(),
      'Health factor should stay above minimum'
    );
  }

  function testRevertOnInsufficientCollateral() public {
    vm.startPrank(bob);
    vm.expectRevert();
    strategy.enterPosition(address(collateralToken), address(borrowToken), INITIAL_BALANCE * 2, 4);
  }

  function testRevertOnExcessiveIteration() public {
    vm.startPrank(bob);
    uint256 maxSafe = strategy.calculateMaxSafeIterations(
      address(collateralToken),
      address(borrowToken)
    );
    vm.expectRevert();
    strategy.enterPosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      maxSafe + 1
    );
  }

  function testHealthFactorMaintenance() public {
    testEnterPosition();

    vm.startPrank(bob);
    (, , , , , uint256 healthFactor) = mockLendingPool.getUserAccountData(bob);
    assertTrue(healthFactor >= strategy.MIN_HEALTH_FACTOR(), 'Health factor below minimum');
  }
}
