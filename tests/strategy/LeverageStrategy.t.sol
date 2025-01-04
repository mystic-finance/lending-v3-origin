// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {LeveragedBorrowingVault} from 'src/core/contracts/protocol/strategies/LeverageStrategy.sol';
import {ERC20Mock as MockERC20} from 'tests/mocks/ERC20Mock.sol';
import '../../src/core/contracts/interfaces/IPool.sol';
import {FlashLoanController} from 'src/core/contracts/protocol/strategies/FlashLoanController.sol';
import {MockSwapController} from 'tests/mocks/SwapController.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {ICreditDelegationToken} from 'src/core/contracts/interfaces/ICreditDelegationToken.sol';
import {AaveV3Flashloaner} from 'src/core/contracts/protocol/strategies/Flashloan/AaveFlashLoan.sol';
import {IAaveOracle} from 'src/core/contracts/interfaces/IAaveOracle.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';

contract LeveragedBorrowingVaultTest is TestnetProcedures {
  // Test Addresses
  address internal deployer;
  address internal owner;
  address internal user;
  address internal anotherUser;

  // Contract instances
  LeveragedBorrowingVault internal vault;
  MockERC20 internal collateralToken;
  MockERC20 internal borrowToken;
  IPool internal lendingPool;
  MockSwapController internal swapController;
  FlashLoanController internal flashLoanController;

  struct UserPosition {
    address user;
    address collateralToken;
    address borrowToken;
    uint256 initialCollateral;
    uint256 totalCollateral;
    uint256 totalBorrowed;
    uint256 leverageMultiplier;
    bool isActive;
  }

  // Constants for testing
  uint256 internal constant INITIAL_BALANCE = 100_000 * 10 ** 18;
  uint256 internal constant INITIAL_COLLATERAL = 10 * 10 ** 18;
  uint256 internal constant LEVERAGE_MULTIPLIER = 5;

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    deployer = address(this);
    user = address(0x100);
    anotherUser = address(0x205);
    vm.startPrank(deployer);

    // Deploy mock tokens
    collateralToken = MockERC20(address(weth)); //new MockERC20('CollateralToken', 'CLT', 18);
    borrowToken = MockERC20(address(usdx)); //new MockERC20('BorrowToken', 'BRT', 18);

    // Deploy mock controllers
    lendingPool = IPool(address(contracts.poolProxy));
    swapController = new MockSwapController(address(contracts.poolProxy));
    AaveV3Flashloaner flashLoanWrapper = new AaveV3Flashloaner(
      address(lendingPool.ADDRESSES_PROVIDER())
    );
    flashLoanController = new FlashLoanController(address(flashLoanWrapper));

    // Deploy the vault
    vault = new LeveragedBorrowingVault(
      address(lendingPool),
      address(swapController),
      address(flashLoanController)
    );

    // Add tokens as allowed
    vault.addAllowedCollateralToken(address(collateralToken));
    vault.addAllowedBorrowToken(address(borrowToken));

    // Mint tokens to user
    vm.startPrank(poolAdmin);
    deal(address(collateralToken), user, INITIAL_BALANCE);
    borrowToken.mint(user, INITIAL_BALANCE);

    deal(address(collateralToken), anotherUser, INITIAL_BALANCE * 1000_000);
    borrowToken.mint(anotherUser, INITIAL_BALANCE * 1000_000);

    deal(address(collateralToken), address(swapController), INITIAL_BALANCE * 20000);
    borrowToken.mint(address(swapController), INITIAL_BALANCE * 20000);

    vm.startPrank(anotherUser);
    borrowToken.approve(address(lendingPool), UINT256_MAX);
    collateralToken.approve(address(lendingPool), UINT256_MAX);

    lendingPool.supply(
      address(borrowToken),
      (INITIAL_BALANCE * 1000_000 * 19) / 20,
      anotherUser,
      0
    );
    lendingPool.supply(
      address(collateralToken),
      (INITIAL_BALANCE * 1000_000 * 19) / 20,
      anotherUser,
      0
    );

    vm.stopPrank();
  }

  // Test helper to prepare user tokens and approvals
  function _prepareUserTokens(address _user) internal {
    vm.startPrank(_user);
    collateralToken.approve(address(vault), INITIAL_COLLATERAL);
    vm.stopPrank();
  }

  // Test: Successful leverage position opening
  function test_openLeveragePosition_Success() public {
    _prepareUserTokens(user);

    vm.startPrank(user);

    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory reserveData2 = lendingPool.getReserveData(
      address(borrowToken)
    );
    IERC20(reserveData.aTokenAddress).approve(address(vault), INITIAL_COLLATERAL * 100_000);
    IERC20(reserveData.aTokenAddress).approve(address(lendingPool), INITIAL_COLLATERAL * 100_000);
    ICreditDelegationToken(reserveData2.variableDebtTokenAddress).approveDelegation(
      address(vault),
      INITIAL_COLLATERAL * 100_000
    );
    // lendingPool.supply(
    //   address(collateralToken),
    //   (INITIAL_COLLATERAL * 19) / 20,
    //   user,
    //   0
    // );
    // lendingPool.setUserUseReserveAsCollateral( address(collateralToken), true);

    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      8
    );
    vm.stopPrank();

    // Validate user position
    LeveragedBorrowingVault.UserPosition[] memory positions = vault.getUserActivePositions(user);

    assertEq(positions[0].user, user);
    assertEq(positions[0].collateralToken, address(collateralToken));
    assertEq(positions[0].borrowToken, address(borrowToken));
    assertEq(positions[0].initialCollateral, INITIAL_COLLATERAL);
    assertTrue(positions[0].isActive);
  }

  // Test: Revert on invalid leverage multiplier
  function test_openLeveragePosition_RevertOn_InvalidLeverage() public {
    _prepareUserTokens(user);

    vm.startPrank(user);
    vm.expectRevert('Invalid leverage');
    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      0 // Invalid leverage
    );

    vm.expectRevert('Invalid leverage');
    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      21 // Exceeds max leverage
    );
    vm.stopPrank();
  }

  function test_openLeveragePosition_CorrectAmounts() public {
    _prepareUserTokens(user);

    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);
    uint256 userInitialBorrowBalance = borrowToken.balanceOf(user);

    vm.startPrank(user);

    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory reserveData2 = lendingPool.getReserveData(
      address(borrowToken)
    );

    IERC20(reserveData.aTokenAddress).approve(address(vault), INITIAL_COLLATERAL * 100_000);
    // IERC20(reserveData.aTokenAddress).approve(address(lendingPool), INITIAL_COLLATERAL * 100_000);
    ICreditDelegationToken(reserveData2.variableDebtTokenAddress).approveDelegation(
      address(vault),
      INITIAL_COLLATERAL * 100_000
    );
    //  lendingPool.supply(
    //   address(collateralToken),
    //   (INITIAL_COLLATERAL * 19) / 20,
    //   user,
    //   0
    // );
    // lendingPool.setUserUseReserveAsCollateral(address(collateralToken), true);

    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      LEVERAGE_MULTIPLIER
    );

    // Verify collateral was deducted
    assertEq(
      collateralToken.balanceOf(user),
      userInitialCollateralBalance - INITIAL_COLLATERAL,
      'Incorrect collateral deduction'
    );

    // Verify position on Aave
    uint256 expectedTotalCollateral = (INITIAL_COLLATERAL * LEVERAGE_MULTIPLIER * 900) / 1000; //col, xpliers, ltv
    uint256 expectedBorrowed = (INITIAL_COLLATERAL * (LEVERAGE_MULTIPLIER) * 900) / (1000e12);

    uint256 actualCollateral = IERC20(reserveData.aTokenAddress).balanceOf(address(user));
    uint256 actualBorrowed = IERC20(reserveData2.variableDebtTokenAddress).balanceOf(address(user));

    assertGt(actualCollateral, expectedTotalCollateral - 0.01e18, 'Incorrect collateral amount');
    assertGt(actualBorrowed, expectedBorrowed - 0.015e6, 'Incorrect borrowed amount');

    vm.stopPrank();
  }

  function test_closeLeveragePosition_CorrectAmounts() public {
    // First open a position
    test_openLeveragePosition_CorrectAmounts();

    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);

    vm.startPrank(user);

    uint256[] memory positions = vault.getUserPositions(user);

    vault.closeLeveragePosition(positions[0]);

    // Verify user received back approximately initial collateral (minus fees)
    uint256 finalBalance = collateralToken.balanceOf(user);
    assertGt(finalBalance, userInitialCollateralBalance, 'User should receive collateral back');

    // Allow for some slippage/fees
    assertGt(
      collateralToken.balanceOf(user),
      userInitialCollateralBalance + INITIAL_COLLATERAL - 0.5e18,
      'Incorrect final balance after closing'
    );

    vm.stopPrank();
  }

  // Test: Revert on non-allowed tokens
  function test_openLeveragePosition_RevertOn_DisallowedTokens() public {
    MockERC20 unknownToken = new MockERC20('UnknownToken', 'UNK', 18);
    _prepareUserTokens(user);

    vm.startPrank(user);
    vm.expectRevert('Collateral token not allowed');
    vault.openLeveragePosition(
      address(unknownToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      LEVERAGE_MULTIPLIER
    );

    vm.expectRevert('Borrow token not allowed');
    vault.openLeveragePosition(
      address(collateralToken),
      address(unknownToken),
      INITIAL_COLLATERAL,
      LEVERAGE_MULTIPLIER
    );
    vm.stopPrank();
  }

  // Test: Closing leverage position
  function test_closeLeveragePosition_Success() public {
    // First, open a position
    _prepareUserTokens(user);
    test_openLeveragePosition_Success();

    // Close position
    vm.startPrank(user);
    // vm.expectEmit(true, false, false, true);
    // emit LeveragePositionClosed(user, INITIAL_COLLATERAL);
    uint256[] memory positions = vault.getUserPositions(user);

    vault.closeLeveragePosition(positions[0]);
    vm.stopPrank();

    // Verify position is closed
    (, , , , , , , bool isActive) = vault.positions(positions[0]);
    assertFalse(isActive);
  }

  // Test: Revert closing position with low health factor
  // function test_closeLeveragePosition_RevertOn_LowHealthFactor() public {
  //   _prepareUserTokens(user);

  //   // Open a highly leveraged position
  //   vm.startPrank(user);

  //   DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
  //     address(collateralToken)
  //   );
  //   DataTypes.ReserveDataLegacy memory reserveData2 = lendingPool.getReserveData(
  //     address(borrowToken)
  //   );

  //   IERC20(reserveData.aTokenAddress).approve(address(vault), INITIAL_COLLATERAL * 100_000);
  //   ICreditDelegationToken(reserveData2.variableDebtTokenAddress).approveDelegation(
  //     address(vault),
  //     INITIAL_COLLATERAL * 100_000
  //   );

  //   // Use maximum leverage
  //   uint256 maxLeverage = 20;
  //   vault.openLeveragePosition(
  //     address(collateralToken),
  //     address(borrowToken),
  //     INITIAL_COLLATERAL,
  //     5
  //   );

  //   // Simulate price drop of collateral by 50%
  //   vm.startPrank(user);
  //   IAaveOracle oracle = IAaveOracle(lendingPool.ADDRESSES_PROVIDER().getPriceOracle());
  //   address[] memory assets = new address[](1);
  //   assets[0] = address(collateralToken);

  //   address[] memory sources = new address[](1);
  //   sources[0] = address(new MockAggregator(900e8));

  //   oracle.setAssetSources(assets, sources);

  //   // Try to close position - should revert due to low health factor
  //   vm.startPrank(user);
  //   bytes4 selector = bytes4(keccak256('LowHealthFactor()'));
  //   vm.expectRevert(selector);
  //   vault.closeLeveragePosition(address(borrowToken));

  //   vm.stopPrank();
  // }

  function testFailCloseNonexistentPosition() public {
    vm.startPrank(user);
    uint256[] memory positions = vault.getUserPositions(user);
    bytes4 selector = bytes4(keccak256('No active position'));
    vm.expectRevert(selector);
    vault.closeLeveragePosition(positions[0]);
    vm.stopPrank();
  }

  // Test: Admin token management
  function test_adminTokenManagement() public {
    vm.startPrank(deployer);

    MockERC20 newToken = new MockERC20('NewToken', 'NEW', 18);

    // Add token
    vault.addAllowedCollateralToken(address(newToken));
    assertTrue(vault.allowedCollateralTokens(address(newToken)));

    // Remove token
    vault.removeAllowedCollateralToken(address(newToken));
    assertFalse(vault.allowedCollateralTokens(address(newToken)));

    vm.stopPrank();
  }

  // Revert on non-owner token management
  function test_revertOn_UnauthorizedTokenManagement() public {
    MockERC20 newToken = new MockERC20('NewToken', 'NEW', 18);

    vm.startPrank(user);
    vm.expectRevert();
    vault.addAllowedCollateralToken(address(newToken));

    vm.expectRevert();
    vault.removeAllowedCollateralToken(address(newToken));
    vm.stopPrank();
  }
}
