// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {FlashMintLiquidator} from 'src/core/contracts/protocol/strategies/Liquidation/FlashMintLiquidatorAave.sol';
import {ERC20Mock as MockERC20} from 'tests/mocks/ERC20Mock.sol';
import '../../src/core/contracts/interfaces/IPool.sol';
import {FlashLoanController} from 'src/core/contracts/protocol/strategies/FlashLoanController.sol';
import {MockSwapController} from 'tests/mocks/SwapController.sol';
import {IAaveOracle} from 'src/core/contracts/interfaces/IAaveOracle.sol';
import {AaveV3Flashloaner} from 'src/core/contracts/protocol/strategies/Flashloan/AaveFlashLoan.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {SwapController} from 'src/core/contracts/protocol/strategies/SwapController.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';

contract FlashMintLiquidatorTest is TestnetProcedures {
  // Test Addresses
  address internal deployer;
  address internal owner;
  address internal liquidator;
  address internal borrower;

  // Contract instances
  FlashMintLiquidator internal liquidatorContract;
  MockERC20 internal collateralToken;
  MockERC20 internal borrowedToken;
  IPool internal lendingPool;
  IAaveOracle internal priceOracle;
  MockSwapController internal swapController;
  FlashLoanController internal flashLender;

  // Constants for testing
  uint256 internal constant INITIAL_BALANCE = 10 * 10 ** 18;
  uint256 internal constant LIQUIDATION_AMOUNT = 12000 * 10 ** 6;
  uint256 internal constant SLIPPAGE_TOLERANCE = 50; // 0.5%%

  function setUp() public {
    initL2TestEnvironment();

    // Set up addresses
    deployer = address(this);
    owner = address(0x123);
    liquidator = address(0x456);
    borrower = address(0x789);
    address user = address(0x758);
    vm.startPrank(deployer);

    // Deploy mock tokens
    collateralToken = MockERC20(address(weth)); //new MockERC20('CollateralToken', 'CLT', 18);
    borrowedToken = MockERC20(address(usdx)); //new MockERC20('BorrowToken', 'BRT', 18);

    // Deploy mock contracts
    lendingPool = IPool(address(contracts.poolProxy));
    // priceOracle = new MockPriceOracle();
    priceOracle = IAaveOracle(lendingPool.ADDRESSES_PROVIDER().getPriceOracle());
    swapController = new MockSwapController(address(contracts.poolProxy));
    AaveV3Flashloaner flashLoanWrapper = new AaveV3Flashloaner(
      address(lendingPool.ADDRESSES_PROVIDER())
    );
    flashLender = new FlashLoanController(address(flashLoanWrapper));
    // flashLender = new MockFlashLender();

    // Deploy the liquidator contract
    vm.startPrank(liquidator);
    liquidatorContract = new FlashMintLiquidator(
      // flashLender,
      SwapController(address(swapController)),
      IPoolAddressesProvider(address(lendingPool.ADDRESSES_PROVIDER())),
      SLIPPAGE_TOLERANCE
    );

    // Set up initial balances
    // collateralToken.mint(borrower, INITIAL_BALANCE);
    vm.startPrank(poolAdmin);
    deal(address(collateralToken), borrower, INITIAL_BALANCE);
    borrowedToken.mint(borrower, INITIAL_BALANCE);
    // deal(address(collateralToken), liquidator, INITIAL_BALANCE);
    // borrowedToken.mint(liquidator, INITIAL_BALANCE);

    deal(address(collateralToken), user, INITIAL_BALANCE * 20000);
    borrowedToken.mint(user, INITIAL_BALANCE * 20000);
    deal(address(collateralToken), address(swapController), INITIAL_BALANCE * 20000);
    borrowedToken.mint(address(swapController), INITIAL_BALANCE * 20000);

    // Approve the liquidator contract to spend tokens
    vm.startPrank(liquidator);
    collateralToken.approve(address(liquidatorContract), INITIAL_BALANCE);
    borrowedToken.approve(address(liquidatorContract), INITIAL_BALANCE);
    vm.stopPrank();

    vm.startPrank(user);
    borrowedToken.approve(address(lendingPool), UINT256_MAX);
    collateralToken.approve(address(lendingPool), UINT256_MAX);

    lendingPool.supply(address(borrowedToken), (INITIAL_BALANCE * 20000 * 19) / 20, user, 0);
    lendingPool.supply(address(collateralToken), (INITIAL_BALANCE * 20000 * 19) / 20, user, 0);
    vm.stopPrank();

    // Set up mock oracle prices
    // address(new MockAggregator(1e8))
  }

  function _updatePrice(address _asset, int256 _price) internal {
    vm.roll(10 days);
    vm.startPrank(poolAdmin);
    address[] memory assets = new address[](1);
    assets[0] = _asset;
    address[] memory sources = new address[](1);

    sources[0] = address(new MockAggregator(_price));
    priceOracle.setAssetSources(assets, sources);
    vm.stopPrank();
  }

  // Helper function to simulate a borrower position
  function _setupBorrowerPosition() internal {
    vm.startPrank(borrower);
    collateralToken.approve(address(lendingPool), INITIAL_BALANCE);
    lendingPool.supply(address(collateralToken), INITIAL_BALANCE, borrower, 0);
    lendingPool.borrow(address(borrowedToken), LIQUIDATION_AMOUNT, 2, 0, borrower);
    vm.stopPrank();
  }

  // Test: Successful liquidation without flash loan
  function test_liquidateWithoutFlashLoan() public {
    _setupBorrowerPosition();

    vm.startPrank(poolAdmin);
    deal(address(collateralToken), liquidator, INITIAL_BALANCE);
    borrowedToken.mint(liquidator, INITIAL_BALANCE);

    uint256 initialLiquidatorBalance = collateralToken.balanceOf(liquidator);

    _updatePrice(address(collateralToken), 1800e8 / 2); // divide price by 5

    vm.startPrank(liquidator);
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT,
      false,
      ''
    );
    vm.stopPrank();

    // Verify the liquidator received the seized collateral
    uint256 finalLiquidatorBalance = collateralToken.balanceOf(liquidator);
    assertGt(
      finalLiquidatorBalance,
      initialLiquidatorBalance,
      'Liquidator did not receive collateral'
    );
  }

  // Test: Successful liquidation with flash loan
  function test_liquidateWithFlashLoan() public {
    _setupBorrowerPosition();

    uint256 initialLiquidatorBalance = borrowedToken.balanceOf(liquidator);

    _updatePrice(address(collateralToken), 1100e8); // divide price by 5
    vm.startPrank(liquidator);
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT,
      false,
      abi.encode(address(borrowedToken), address(collateralToken), 100) // Swap path
    );
    vm.stopPrank();

    // Verify the liquidator received the seized collateral
    uint256 finalLiquidatorBalance = borrowedToken.balanceOf(liquidator);
    assertGt(
      finalLiquidatorBalance,
      initialLiquidatorBalance,
      'Liquidator did not receive collateral'
    );
  }

  // Test: Revert if the liquidator is not authorized
  function test_revertIfNotLiquidator() public {
    _setupBorrowerPosition();

    vm.startPrank(address(0x999)); // Unauthorized address
    vm.expectRevert();
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT,
      false,
      ''
    );
    vm.stopPrank();
  }

  // Test: Revert if the borrower has no debt
  function test_revertIfNoDebt() public {
    vm.startPrank(liquidator);
    vm.expectRevert();
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT,
      false,
      ''
    );
    vm.stopPrank();
  }

  // Test: Revert if the liquidation amount exceeds the borrower's debt
  function test_revertIfAmountExceedsDebt() public {
    _setupBorrowerPosition();

    vm.startPrank(liquidator);
    vm.expectRevert();
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT * 2, // Exceeds debt
      false,
      ''
    );
    vm.stopPrank();
  }

  // Test: Revert if the swap fails due to slippage
  function test_revertIfSwapFails() public {
    _setupBorrowerPosition();

    // Set up a high slippage tolerance to simulate a failed swap
    vm.startPrank(owner);
    liquidatorContract.setSlippageTolerance(10_000); // 100% slippage tolerance
    vm.stopPrank();

    vm.startPrank(liquidator);
    vm.expectRevert();
    liquidatorContract.liquidate(
      address(borrowedToken),
      address(collateralToken),
      borrower,
      LIQUIDATION_AMOUNT,
      false,
      abi.encode(address(borrowedToken), address(collateralToken), 3000)
    );
    vm.stopPrank();
  }

  // Test: Revert if the liquidation is not profitable
  // function test_revertIfNotProfitable() public {
  //   _setupBorrowerPosition();

  //   // Set up a low collateral price to make the liquidation unprofitable
  //   _updatePrice(address(collateralToken), 1800e8 / 10);

  //   vm.startPrank(liquidator);
  //   vm.expectRevert();
  //   liquidatorContract.liquidate(
  //     address(borrowedToken),
  //     address(collateralToken),
  //     borrower,
  //     LIQUIDATION_AMOUNT,
  //     false,
  //     abi.encode(address(borrowedToken), address(collateralToken), 300)
  //   );
  //   vm.stopPrank();
  // }
}
