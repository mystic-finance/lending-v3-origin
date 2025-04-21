// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ILeveragedBorrowingVault02} from 'src/core/contracts/interfaces/ILeveragedBorrowingVault02.sol';
import {LeveragedBorrowingVault02} from 'src/core/contracts/protocol/strategies/LeverageStrategy02.sol';
import {ERC20Mock as MockERC20} from 'tests/mocks/ERC20Mock.sol';
import '../../src/core/contracts/interfaces/IPool.sol';
import {FlashLoanController} from 'src/core/contracts/protocol/strategies/FlashLoanController.sol';
import {MockSwapController} from 'tests/mocks/SwapController.sol';
import {SwapController} from 'src/core/contracts/protocol/strategies/SwapController.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {ICreditDelegationToken} from 'src/core/contracts/interfaces/ICreditDelegationToken.sol';
import {AaveV3Flashloaner} from 'src/core/contracts/protocol/strategies/Flashloan/AaveFlashLoan.sol';
import {IAaveOracle} from 'src/core/contracts/interfaces/IAaveOracle.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {AmbientSwap} from 'src/core/contracts/protocol/strategies/Swap/AmbientSwapper.sol';
import {MaverickSwap} from 'src/core/contracts/protocol/strategies/Swap/MaverickSwapper.sol';

contract LeveragedBorrowingVault02Fork2Test is TestnetProcedures {
  // Test Addresses
  address internal deployer;
  address internal owner;
  address internal user;
  address internal anotherUser;

  // Contract instances
  LeveragedBorrowingVault02 internal vault;
  IERC20 internal collateralToken;
  IERC20 internal borrowToken;
  IPool internal lendingPool;
  SwapController internal swapController;
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
  uint256 internal constant INITIAL_COLLATERAL = 1 * 10 ** 15;
  uint256 internal constant LEVERAGE_MULTIPLIER = 3;

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    deployer = address(this);
    user = 0x18E1EEC9Fa5D77E472945FE0d48755386f28443c;
    // anotherUser = address(0x205);
    vm.startPrank(0x18E1EEC9Fa5D77E472945FE0d48755386f28443c);

    //   Aave V3 Batch Listing
    //   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    //   ambientSwapper 0x27846f8D7ab54f05be167628cd40B48e620e768B
    //   flashLoaner 0xA3954b212F70C41c2f54fe6E5684BAa09FF775b3
    //   swapController 0xC473008F1e9cac6Ef14690c7444f3cf391f6B526
    //   flashloanController 0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A
    //   loopStrategy 0x0ffbaF1Fb8De90DdA77feb3963feFE5204091Cb0
    //   leverageStrategy 0x94F92CdA0f9017f4B8daab1a6b681C04a4871140
    // peth-pusd. peth-usdc, pusd-usdc, - 0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73 - peth, 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F - pusd, 0x3938A812c54304fEffD266C7E2E70B48F9475aD6 - usdc

    // Deploy mock tokens
    collateralToken = IERC20(0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1); //new MockERC20('CollateralToken', 'CLT', 18);
    borrowToken = IERC20(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F); //new MockERC20('BorrowToken', 'BRT', 18);

    // Deploy mock controllers
    lendingPool = IPool(0xCE192A6E105cD8dd97b8Dedc5B5b263B52bb6AE0);

    // AaveV3Flashloaner flashLoanWrapper = AaveV3Flashloaner(
    //   address(lendingPool.ADDRESSES_PROVIDER())
    // );
    // flashLoanController = FlashLoanController(0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A);
    // AaveV3Flashloaner flashLoanWrapper = new AaveV3Flashloaner(
    //   address(lendingPool.ADDRESSES_PROVIDER())
    // );
    // FlashLoanController flashLoanController = new FlashLoanController(address(flashLoanWrapper));

    // Deploy the vault
    AmbientSwap swap = new AmbientSwap(
      0xAaAaAAAA81a99d2a05eE428eC7a1d8A3C2237D85,
      address(lendingPool)
    );
    // MaverickSwap swap = new MaverickSwap(
    //   0x056A588AfdC0cdaa4Cab50d8a4D2940C5D04172E,
    //   0xf245948e9cf892C351361d298cc7c5b217C36D82
    // ); //factory, quoter

    swapController = new SwapController(address(swap));
    // vault = new LeveragedBorrowingVault(
    //   0xd5b3495C5e059a23Bea726166E3C46b0Cb3b42Ab,
    //   address(swapController),
    //   address(flashLoanController)
    // );
    vault = new LeveragedBorrowingVault02(
      0xCE192A6E105cD8dd97b8Dedc5B5b263B52bb6AE0,
      address(swapController), //0x9e05D90f40ABd231C7B482449de9e1872F94A3c4,
      0xDc559b3af6aB03B82753f0808cc33eB1eeb51734
    );
    // vault = LeveragedBorrowingVault(0xC5b1009a2C098378e7a08900e4b6e46a1bF32Da2);

    vault.addAllowedBorrowToken(address(borrowToken));
    vault.addAllowedBorrowToken(address(collateralToken));
    // vault.addAllowedBorrowToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    // vault.addAllowedBorrowToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    vault.addAllowedCollateralToken(address(collateralToken));
    vault.addAllowedCollateralToken(address(borrowToken));
    // vault.addAllowedCollateralToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    // vault.addAllowedCollateralToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    // new ambient, new swap controller, new vault

    // Add tokens as allowed
    // vault.addAllowedCollateralToken(address(collateralToken));
    // vault.addAllowedBorrowToken(address(borrowToken));

    // Mint tokens to user
    // vm.startPrank(poolAdmin);
    deal(address(collateralToken), user, INITIAL_BALANCE);
    // borrowToken.mint(user, INITIAL_BALANCE);

    // deal(address(collateralToken), anotherUser, INITIAL_BALANCE * 1000_000);
    // borrowToken.mint(anotherUser, INITIAL_BALANCE * 1000_000);

    // deal(address(collateralToken), address(swapController), INITIAL_BALANCE * 20000);
    // borrowToken.mint(address(swapController), INITIAL_BALANCE * 20000);

    // vm.startPrank(anotherUser);
    // borrowToken.approve(address(lendingPool), UINT256_MAX);
    // address(collateralToken).call{value: INITIAL_COLLATERAL}('');
    collateralToken.approve(address(lendingPool), UINT256_MAX);

    // lendingPool.supply(
    //   address(borrowToken),
    //   (INITIAL_BALANCE * 1000_000 * 19) / 20,
    //   anotherUser,
    //   0
    // );
    // lendingPool.supply(
    //   address(collateralToken),
    //   (INITIAL_BALANCE * 1000_000 * 19) / 20,
    //   anotherUser,
    //   0
    // );

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
    // IERC20(reserveData.aTokenAddress).approve(address(lendingPool), INITIAL_COLLATERAL * 100_000);
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
    console.log(address(collateralToken) < address(borrowToken));

    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      LEVERAGE_MULTIPLIER
    );
    vm.stopPrank();

    // Validate user position
    uint256[] memory positions = vault.getUserActivePositionIds(user);
    // LeveragedBorrowingVault.UserPosition memory position = vault.positions(positions[0]);

    // assertEq(position.user, user);
    // assertEq(position.collateralToken, address(collateralToken));
    // assertEq(position.borrowToken, address(borrowToken));
    // assertEq(position.initialCollateral, INITIAL_COLLATERAL);
    // assertTrue(position.isActive);
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
    uint256 collateral1 = IERC20(reserveData.aTokenAddress).balanceOf(address(user));
    uint256 borrow1 = IERC20(reserveData2.variableDebtTokenAddress).balanceOf(address(user));

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
    uint256 expectedTotalCollateral = (INITIAL_COLLATERAL * LEVERAGE_MULTIPLIER * 950) / 1000; //col, xpliers, ltv
    // uint256 expectedBorrowed = (INITIAL_COLLATERAL * (LEVERAGE_MULTIPLIER - 1) * 900) / (1000e8);
    uint256 collateral2 = IERC20(reserveData.aTokenAddress).balanceOf(address(user));
    uint256 borrow2 = IERC20(reserveData2.variableDebtTokenAddress).balanceOf(address(user));
    uint256 actualCollateral = collateral2 - collateral1;
    uint256 actualBorrowed = borrow2 - borrow1;

    assertGt(actualCollateral, expectedTotalCollateral - 0.1e14, 'Incorrect collateral amount');
    assertGt(actualBorrowed, 0, 'Incorrect borrowed amount');

    vm.stopPrank();
  }

  function test_closeLeveragePosition_CorrectAmounts() public {
    // First open a position
    uint256 userMainCollateralBalance = collateralToken.balanceOf(user);
    test_openLeveragePosition_CorrectAmounts();

    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);
    vm.startPrank(user);

    uint256[] memory positions = vault.getUserPositions(user);

    vault.closeLeveragePosition(address(collateralToken), address(borrowToken));

    // Verify user received back approximately initial collateral (minus fees)
    uint256 finalBalance = collateralToken.balanceOf(user);
    assertGt(
      finalBalance,
      userMainCollateralBalance - 0.1e15,
      'User should receive collateral back'
    );

    // Allow for some slippage/fees
    assertGt(
      collateralToken.balanceOf(user),
      userInitialCollateralBalance + INITIAL_COLLATERAL - 0.1e15,
      'Incorrect final balance after closing'
    );

    assertGt(
      finalBalance - userInitialCollateralBalance,
      INITIAL_COLLATERAL - 0.1e15,
      'Incorrect final collateral balance after closing'
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

    vault.closeLeveragePosition(address(collateralToken), address(borrowToken));
    vm.stopPrank();

    // Verify position is closed
    (, , , , , , , bool isActive) = vault.positions(positions[0]);
    assertFalse(isActive);
  }

  // Helper function to verify user balances after position updates
  function _verifyUserBalances(
    address _user,
    uint256 expectedCollateralBalance,
    uint256 expectedBorrowBalance
  ) internal {
    uint256 actualCollateralBalance = collateralToken.balanceOf(_user);
    uint256 actualBorrowBalance = borrowToken.balanceOf(_user);
    console.log(expectedCollateralBalance, expectedBorrowBalance);

    assert(actualCollateralBalance >= expectedCollateralBalance);
    assert(actualBorrowBalance >= expectedBorrowBalance);
  }

  // Test: Adding to a position
  function test_addToPosition_Success() public {
    // First, open a position
    _prepareUserTokens(user);
    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    // Add collateral to the position
    uint256 additionalCollateral = 1 * 10 ** 15 + INITIAL_COLLATERAL;
    deal(address(collateralToken), user, additionalCollateral);
    uint256 initialCollateralBalance = collateralToken.balanceOf(user);

    vm.startPrank(user);
    collateralToken.approve(address(vault), additionalCollateral);

    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      additionalCollateral,
      LEVERAGE_MULTIPLIER
    );

    // Verify position is updated
    (, , , , uint256 totalCollateral, uint256 totalBorrowed, , bool isActive) = vault.positions(
      positionId
    );
    assertGt(totalCollateral, totalCollateralOld, 'Collateral not increased');
    assertGt(
      totalCollateral,
      ((INITIAL_COLLATERAL + 1 * 10 ** 15) * LEVERAGE_MULTIPLIER) - 0.4e15,
      'Collateral not updated'
    );
    assertGt(totalBorrowed, totalBorrowedOld, 'Borrowed amount not updated');

    // assertGt(actualCollateralBalance, userInitialCollateralBalance - INITIAL_COLLATERAL - 1 * 10 ** 15 - 1, 'Incorrect Balance');
    console.log(userInitialCollateralBalance, INITIAL_COLLATERAL);

    //Verify user balances
    // _verifyUserBalances(
    //   user,
    //   userInitialCollateralBalance - INITIAL_COLLATERAL - 1 * 10 ** 15, // Expected collateral balance
    //   0 // Expected borrow balance
    // );

    vm.stopPrank();
  }

  // Test: Removing from a position
  function test_removeFromPosition_Success() public {
    // First, open a position
    _prepareUserTokens(user);
    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    // Remove collateral from the position
    uint256 collateralToRemove = 0.5e15;
    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    console.log(vault.totalCollateral());
    console.log(vault.totalBorrowed());

    vm.startPrank(user);
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL - collateralToRemove,
      LEVERAGE_MULTIPLIER
    );

    // Verify position is updated
    (, , , , uint256 totalCollateral, uint256 totalBorrowed, , bool isActive) = vault.positions(
      positionId
    );
    assertGt(totalCollateralOld, totalCollateral, 'Collateral not decreased');
    assertGt(
      ((INITIAL_COLLATERAL + 1 * 10 ** 15) * LEVERAGE_MULTIPLIER) - 0.5e15,
      totalCollateral,
      'Collateral not updated'
    );
    assertGt(totalBorrowedOld, totalBorrowed, 'Borrowed amount not updated');

    uint256 actualCollateralBalance = collateralToken.balanceOf(user);
    assertGt(
      actualCollateralBalance,
      userInitialCollateralBalance - INITIAL_COLLATERAL + collateralToRemove - 0.1e15,
      'Incorrect Balance'
    );

    // Verify user balances
    // _verifyUserBalances(
    //   user,
    //   userInitialCollateralBalance - INITIAL_COLLATERAL + collateralToRemove, // Expected collateral balance
    //   0 // Expected borrow balance
    // );

    vm.stopPrank();
  }

  // Test: Updating leverage multiplier
  function test_updateLeverageMultiplier_Success() public {
    // First, open a position
    _prepareUserTokens(user);
    uint256 userInitialCollateralBalance = collateralToken.balanceOf(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    // Update leverage multiplier
    uint256 newLeverageMultiplier = 4;

    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    vm.startPrank(user);
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      newLeverageMultiplier
    );

    // Verify position is updated
    (
      ,
      ,
      ,
      ,
      uint256 totalCollateral,
      uint256 totalBorrowed,
      uint256 leverageMultiplier,
      bool isActive
    ) = vault.positions(positionId);
    assertGt(totalCollateral, totalCollateralOld, 'Collateral not increased');
    assertGt(totalCollateral, ((INITIAL_COLLATERAL) * 4) - 0.1e15, 'Collateral not updated');
    assertGt(totalBorrowed, totalBorrowedOld, 'Borrowed amount not updated');

    // Verify user balances
    _verifyUserBalances(
      user,
      userInitialCollateralBalance - INITIAL_COLLATERAL, // Expected collateral balance
      0 // Expected borrow balance
    );

    vm.stopPrank();
  }

  function test_updateReduceLeverageMultiplier_Success() public {
    // First, open a position
    _prepareUserTokens(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    // Update leverage multiplier
    uint256 newLeverageMultiplier = 2;

    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    vm.startPrank(user);
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      newLeverageMultiplier
    );

    // Verify position is updated
    (
      ,
      ,
      ,
      ,
      uint256 totalCollateral,
      uint256 totalBorrowed,
      uint256 leverageMultiplier,
      bool isActive
    ) = vault.positions(positionId);
    assertGt(totalCollateralOld, totalCollateral - 0.01e15, 'Collateral not decreased');

    assertGt(((INITIAL_COLLATERAL) * 3), totalCollateral - 0.01e15, 'Collateral not updated');
    assertGt(totalBorrowedOld, totalBorrowed - 1, 'Borrowed amount not updated');

    // Verify user balances
    // _verifyUserBalances(
    //   user,
    //   INITIAL_BALANCE - INITIAL_COLLATERAL, // Expected collateral balance
    //   0 // Expected borrow balance
    // );

    vm.stopPrank();
  }

  // Test: Revert on updating non-existent position
  function test_updateLeveragePosition_RevertOn_NonExistentPosition() public {
    _prepareUserTokens(user);

    vm.startPrank(user);
    vm.expectRevert('No active position');
    vault.updateLeveragePosition(address(0), address(1), INITIAL_COLLATERAL, LEVERAGE_MULTIPLIER);
    vm.stopPrank();
  }

  // Test: Revert on updating position with invalid leverage
  function test_updateLeveragePosition_RevertOn_InvalidLeverage() public {
    // First, open a position
    _prepareUserTokens(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    vm.startPrank(user);
    vm.expectRevert('Invalid leverage');
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      0
    ); // Invalid leverage

    vm.expectRevert('Invalid leverage');
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      21
    ); // Exceeds max leverage
    vm.stopPrank();
  }

  // Test: Revert on updating position with low health factor
  function test_updateLeveragePosition_RevertOn_LowHealthFactor() public {
    // First, open a position
    _prepareUserTokens(user);
    test_openLeveragePosition_Success();

    uint256[] memory positions = vault.getUserPositions(user);
    uint256 positionId = positions[0];

    // Simulate price drop of collateral by 50%
    vm.startPrank(user);
    IAaveOracle oracle = IAaveOracle(lendingPool.ADDRESSES_PROVIDER().getPriceOracle());
    address[] memory assets = new address[](1);
    assets[0] = address(collateralToken);

    address[] memory sources = new address[](1);
    sources[0] = address(new MockAggregator(8e3));

    vm.startPrank(user);
    oracle.setAssetSources(assets, sources);

    // Try to update position - should revert due to low health factor
    vm.expectRevert('Position health is too low');
    vault.updateLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      LEVERAGE_MULTIPLIER
    );

    vm.stopPrank();
  }

  // Test: Revert closing position with low health factor
  function test_closeLeveragePosition_RevertOn_LowHealthFactor() public {
    _prepareUserTokens(user);

    // Open a highly leveraged position
    vm.startPrank(user);

    DataTypes.ReserveDataLegacy memory reserveData = lendingPool.getReserveData(
      address(collateralToken)
    );
    DataTypes.ReserveDataLegacy memory reserveData2 = lendingPool.getReserveData(
      address(borrowToken)
    );

    IERC20(reserveData.aTokenAddress).approve(address(vault), INITIAL_COLLATERAL * 100_000);
    ICreditDelegationToken(reserveData2.variableDebtTokenAddress).approveDelegation(
      address(vault),
      INITIAL_COLLATERAL * 100_000
    );

    // Use maximum leverage
    uint256 maxLeverage = 20;
    vault.openLeveragePosition(
      address(collateralToken),
      address(borrowToken),
      INITIAL_COLLATERAL,
      4
    );

    // Simulate price drop of collateral by 50%
    vm.startPrank(user);
    IAaveOracle oracle = IAaveOracle(lendingPool.ADDRESSES_PROVIDER().getPriceOracle());
    address[] memory assets = new address[](1);
    assets[0] = address(collateralToken);

    address[] memory sources = new address[](1);
    sources[0] = address(new MockAggregator(8e3));

    oracle.setAssetSources(assets, sources);

    // Try to close position - should revert due to low health factor
    vm.startPrank(user);
    bytes4 selector = bytes4(keccak256('LowHealthFactor()'));
    vm.expectRevert(selector);
    vault.closeLeveragePosition(address(collateralToken), address(borrowToken));

    vm.stopPrank();
  }

  // function test_CloseNonexistentPosition() public {
  //   vm.startPrank(user);
  //   uint256[] memory positions = vault.getUserPositions(user);
  //   bytes4 selector = bytes4(keccak256('No active position'));
  //   vm.expectRevert(selector);
  //   vault.closeLeveragePosition(address(collateralToken), address(borrowToken));
  //   vm.stopPrank();
  // }

  // Test: Admin token management
  function test_adminTokenManagement() public {
    vm.startPrank(user);

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

    // vm.startPrank(user);
    vm.startPrank(0x37081C7c25284CeE72947aF90A13B7402f2eB6fb);
    vm.expectRevert();
    vault.addAllowedCollateralToken(address(newToken));

    vm.expectRevert();
    vault.removeAllowedCollateralToken(address(newToken));
    vm.stopPrank();
  }
}
