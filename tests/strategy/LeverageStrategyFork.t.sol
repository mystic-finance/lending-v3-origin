// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {LeveragedBorrowingVault} from 'src/core/contracts/protocol/strategies/LeverageStrategy.sol';
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
contract LeveragedBorrowingVaultForkTest is TestnetProcedures {
  // Test Addresses
  address internal deployer;
  address internal owner;
  address internal user;
  address internal anotherUser;

  // Contract instances
  LeveragedBorrowingVault internal vault;
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
  uint256 internal constant INITIAL_COLLATERAL = 1 * 10 ** 13;
  uint256 internal constant LEVERAGE_MULTIPLIER = 3;

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    deployer = address(this);
    user = 0xf927Efdc25E14F33C6402F8A1dCEa5911051e749;
    // anotherUser = address(0x205);
    vm.startPrank(0x37081C7c25284CeE72947aF90A13B7402f2eB6fb);

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
    collateralToken = IERC20(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73); //new MockERC20('CollateralToken', 'CLT', 18);
    borrowToken = IERC20(0x3938A812c54304fEffD266C7E2E70B48F9475aD6); //new MockERC20('BorrowToken', 'BRT', 18);

    // Deploy mock controllers
    lendingPool = IPool(0xd5b3495C5e059a23Bea726166E3C46b0Cb3b42Ab);

    // AaveV3Flashloaner flashLoanWrapper = AaveV3Flashloaner(
    //   address(lendingPool.ADDRESSES_PROVIDER())
    // );
    flashLoanController = FlashLoanController(0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A);

    // Deploy the vault
    AmbientSwap ambientSwapper = new AmbientSwap(
      0xAaAaAAAA81a99d2a05eE428eC7a1d8A3C2237D85,
      0xd5b3495C5e059a23Bea726166E3C46b0Cb3b42Ab
    );

    swapController = new SwapController(address(ambientSwapper));
    // swapController = SwapController(0x0f8d9480ca937441c166E39e2d9f90a7A6031194);
    // swapController.updateSwapper(address(ambientSwapper));

    vault = new LeveragedBorrowingVault(
      address(lendingPool),
      address(swapController),
      address(flashLoanController)
    );
    // vault = LeveragedBorrowingVault(0x5C4DdF6b3d65E7cfF4A6b0B1Ee4DcF45b4A08246);

    vault.addAllowedBorrowToken(0x3938A812c54304fEffD266C7E2E70B48F9475aD6);
    vault.addAllowedBorrowToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    vault.addAllowedBorrowToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    vault.addAllowedBorrowToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    vault.addAllowedCollateralToken(0x3938A812c54304fEffD266C7E2E70B48F9475aD6);
    vault.addAllowedCollateralToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    vault.addAllowedCollateralToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    vault.addAllowedCollateralToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    // new ambient, new swap controller, new vault

    // Add tokens as allowed
    // vault.addAllowedCollateralToken(address(collateralToken));
    // vault.addAllowedBorrowToken(address(borrowToken));

    // Mint tokens to user
    // vm.startPrank(poolAdmin);
    // deal(address(collateralToken), user, INITIAL_BALANCE);
    // borrowToken.mint(user, INITIAL_BALANCE);

    // deal(address(collateralToken), anotherUser, INITIAL_BALANCE * 1000_000);
    // borrowToken.mint(anotherUser, INITIAL_BALANCE * 1000_000);

    // deal(address(collateralToken), address(swapController), INITIAL_BALANCE * 20000);
    // borrowToken.mint(address(swapController), INITIAL_BALANCE * 20000);

    // vm.startPrank(anotherUser);
    // borrowToken.approve(address(lendingPool), UINT256_MAX);
    // collateralToken.approve(address(lendingPool), UINT256_MAX);

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

    vault.closeLeveragePosition(positions[0]);

    // Verify user received back approximately initial collateral (minus fees)
    uint256 finalBalance = collateralToken.balanceOf(user);
    assertGt(
      finalBalance,
      userMainCollateralBalance - 0.1e13,
      'User should receive collateral back'
    );

    // Allow for some slippage/fees
    assertGt(
      collateralToken.balanceOf(user),
      userInitialCollateralBalance + INITIAL_COLLATERAL - 0.1e13,
      'Incorrect final balance after closing'
    );

    assertGt(
      finalBalance - userInitialCollateralBalance,
      INITIAL_COLLATERAL - 0.1e13,
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

    vault.closeLeveragePosition(positions[0]);
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

    assert(actualCollateralBalance>= expectedCollateralBalance);
    assert(actualBorrowBalance>= expectedBorrowBalance);
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
    uint256 additionalCollateral = 1 * 10 ** 13 + INITIAL_COLLATERAL;
    deal(address(collateralToken), user, additionalCollateral);
    uint256 initialCollateralBalance = collateralToken.balanceOf(user);

    vm.startPrank(user);
    collateralToken.approve(address(vault), additionalCollateral);

    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    vault.updateLeveragePosition(positionId, additionalCollateral, LEVERAGE_MULTIPLIER);

    // Verify position is updated
    (, , , , uint256 totalCollateral, uint256 totalBorrowed, , bool isActive) = vault.positions(
      positionId
    );
    assertGt(totalCollateral, totalCollateralOld, 'Collateral not increased');
    assertGt(
      totalCollateral,
      ((INITIAL_COLLATERAL + 1 * 10 ** 13) * LEVERAGE_MULTIPLIER) - 0.4e13,
      'Collateral not updated'
    );
    assertGt(totalBorrowed, totalBorrowedOld, 'Borrowed amount not updated');

    
    // assertGt(actualCollateralBalance, userInitialCollateralBalance - INITIAL_COLLATERAL - 1 * 10 ** 13 - 1, 'Incorrect Balance');

    //Verify user balances
    _verifyUserBalances(
      user,
      userInitialCollateralBalance - INITIAL_COLLATERAL - 1 * 10 ** 13, // Expected collateral balance
      0 // Expected borrow balance
    );

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
    uint256 collateralToRemove = 5 * 10 ** 12;
    (, , , , uint256 totalCollateralOld, uint256 totalBorrowedOld, , ) = vault.positions(
      positionId
    );

    vm.startPrank(user);
    vault.updateLeveragePosition(
      positionId,
      INITIAL_COLLATERAL - collateralToRemove,
      LEVERAGE_MULTIPLIER
    );

    // Verify position is updated
    (, , , , uint256 totalCollateral, uint256 totalBorrowed, , bool isActive) = vault.positions(
      positionId
    );
    assertGt(totalCollateralOld, totalCollateral, 'Collateral not decreased');
    assertGt(
      ((INITIAL_COLLATERAL + 1 * 10 ** 13) * LEVERAGE_MULTIPLIER) - 0.4e13,
      totalCollateral,
      'Collateral not updated'
    );
    assertGt(totalBorrowedOld, totalBorrowed, 'Borrowed amount not updated');

    uint256 actualCollateralBalance = collateralToken.balanceOf(user);
    assertGt(actualCollateralBalance, userInitialCollateralBalance - INITIAL_COLLATERAL + collateralToRemove - 0.1e13, 'Incorrect Balance');

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
    vault.updateLeveragePosition(positionId, INITIAL_COLLATERAL, newLeverageMultiplier);

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
    assertGt(
      totalCollateral,
      ((INITIAL_COLLATERAL) * 4) - 0.1e13,
      'Collateral not updated'
    );
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
    vault.updateLeveragePosition(positionId, INITIAL_COLLATERAL, newLeverageMultiplier);

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
    assertGt(totalCollateralOld, totalCollateral, 'Collateral not decreased');
   
    assertGt(
      ((INITIAL_COLLATERAL) * 2) - 0.1e13,
      totalCollateral,
      
      'Collateral not updated'
    );
    assertGt(totalBorrowedOld, totalBorrowed, 'Borrowed amount not updated');

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
    vault.updateLeveragePosition(999, INITIAL_COLLATERAL, LEVERAGE_MULTIPLIER);
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
    vault.updateLeveragePosition(positionId, INITIAL_COLLATERAL, 0); // Invalid leverage

    vm.expectRevert('Invalid leverage');
    vault.updateLeveragePosition(positionId, INITIAL_COLLATERAL, 21); // Exceeds max leverage
    vm.stopPrank();
  }

  // Test: Revert on updating position with low health factor
  // function test_updateLeveragePosition_RevertOn_LowHealthFactor() public {
  //   // First, open a position
  //   _prepareUserTokens(user);
  //   test_openLeveragePosition_Success();

  //   uint256[] memory positions = vault.getUserPositions(user);
  //   uint256 positionId = positions[0];

  //   // Simulate price drop of collateral by 50%
  //   vm.startPrank(user);
  //   IAaveOracle oracle = IAaveOracle(lendingPool.ADDRESSES_PROVIDER().getPriceOracle());
  //   address[] memory assets = new address[](1);
  //   assets[0] = address(collateralToken);

  //   address[] memory sources = new address[](1);
  //   sources[0] = address(new MockAggregator(900e8));

  //   vm.startPrank(poolAdmin);
  //   oracle.setAssetSources(assets, sources);

  //   // Try to update position - should revert due to low health factor
  //   vm.expectRevert('Position health is too low');
  //   vault.updateLeveragePosition(positionId, INITIAL_COLLATERAL, LEVERAGE_MULTIPLIER);

  //   vm.stopPrank();
  // }

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
    vm.startPrank(0x37081C7c25284CeE72947aF90A13B7402f2eB6fb);

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
