// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import 'src/core/contracts/protocol/vault/Vault.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import '../mocks/ERC20Mock.sol'; // Mock ERC20 for testing
import '../../src/core/contracts/interfaces/IPool.sol';
import '../../src/core/contracts/dependencies/chainlink/AggregatorInterface.sol';
import '../../src/core/contracts/interfaces/IMysticVault.sol';
import '../../src/core/contracts/interfaces/ICreditDelegationToken.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';

contract MysticVaultTest is TestnetProcedures {
  MysticVault vault;
  ERC20Mock baseAsset;
  ERC20Mock collateralAsset;
  ERC20Mock aToken;
  address MOCK_PRICE_FEED;
  address owner = address(10);
  address curator = address(101);
  address curatorNew = address(102);
  // address bob = address(1567);
  address poolAddress;

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    curator = address(0x1);
    bob = address(0x2);
    baseAsset = ERC20Mock(address(usdx)); //new ERC20Mock('Base Asset', 'BA', 18);
    collateralAsset = ERC20Mock(address(wbtc)); //new ERC20Mock('Collateral Asset', 'CA', 18);
    aToken = new ERC20Mock('Test AToken', 'TAT', 18);
    MOCK_PRICE_FEED = address(new MockAggregator(1e8));
    poolAddress = address(contracts.poolProxy);
    vault = new MysticVault(
      address(baseAsset),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100, // 1%
      owner,
      'Mystic Vault',
      'AVLT'
    );

    vm.startPrank(poolAdmin);
    baseAsset.mint(owner, 10000e18); // Mint some base asset for testing
    baseAsset.mint(bob, 10000e18); // Mint some base asset for testing
    collateralAsset.mint(bob, 10000e18);
    // vault.addCurator(curator);

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 10000e18); //approvals ahead of testing
  }

  function testAddCurator() public {
    vm.startPrank(curator);
    vault.addCurator(curatorNew);
    assertTrue(vault.curators(curatorNew), 'Curator should be added');
  }

  function testRemoveCurator() public {
    vm.startPrank(curator);
    vault.addCurator(curatorNew);
    vault.removeCurator(curatorNew);
    assertFalse(vault.curators(curatorNew), 'Curator should be removed');
  }

  function testAddAssetAllocation() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(poolAddress, address(baseAsset));

    assertEq(allocationPercentage, 1000, 'Asset allocation should be added');
    assertEq(
      vault.poolAssets(poolAddress, 0),
      address(baseAsset),
      'Asset should be in pool assets'
    );
  }

  // function testAddAssetAllocationBatch() public {
  //   vm.startPrank(curator);

  //   vault.addMysticPool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
  //   vault.addMysticPool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 5000, address(0x5)); // 10%
  //   (, , , uint256 allocationPercentage) = vault.assetAllocations(poolAddress, address(baseAsset));

  //   assertEq(allocationPercentage, 1000, 'Asset allocation should be added');

  //   (, , , uint256 allocationPercentage2) = vault.assetAllocations(
  //     address(0x5),
  //     address(baseAsset)
  //   );

  //   assertEq(allocationPercentage2, 5000, 'Asset allocation should be added');
  //   assertEq(
  //     vault.poolAssets(poolAddress, 0),
  //     address(baseAsset),
  //     'Asset should be in pool assets'
  //   );
  // }

  function testUpdateAssetAllocation() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    vault.updateAssetAllocation(address(baseAsset), MOCK_PRICE_FEED, 500,poolAddress); // Update to 5%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(poolAddress, address(baseAsset));

    assertEq(allocationPercentage, 500, 'Asset allocation should be updated');
  }

  function testReallocate() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    vault.reallocate(address(baseAsset), poolAddress, 500); // Reallocate to 5%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(poolAddress, address(baseAsset));

    assertEq(allocationPercentage, 500, 'Asset allocation should be reallocated');
  }

  function testDeposit() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 8000, poolAddress); // 10%

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 100e18);
    vault.deposit(100e18, bob);
    address asset = vault.asset();
    console.log(asset);

    assertEq(vault.totalAssets(), 100e18, 'Total assets should reflect the deposit');
    assertEq(baseAsset.balanceOf(bob), 900e18, 'Owner should have 900 ether left');
    assertEq(vault.balanceOf(bob), 100e18, 'Bob should have 100 ether');
    assert(vault.totalSupply() >= 100e18);
  }

  function testWithdraw() public {
    testDeposit();

    vm.startPrank(bob);
    // baseAsset.approve(address(vault), 100e18);
    // vault.deposit(100e18, bob);
    console.log(vault.balanceOf(bob));
    vault.requestWithdrawal(50e18);
    uint fee = (100 * 50e18) / 10000;
    uint remaining = 100e18 - 50e18 + fee;

    vm.warp(block.timestamp + 2 days); // Move time forward to meet timelock testDeposit
    vault.withdraw(50e18, bob, bob);

    assertEq(vault.totalAssets(), remaining, 'Total assets should reflect the withdrawal');
    assertEq(
      baseAsset.balanceOf(bob),
      950e18 - fee,
      'Bob should less than 950 ether after withdrawal'
    );
  }

  function initialBorrowPrep() public {
    testDeposit();
    vm.startPrank(bob);
    address variableDebtTokenAddress = IPool(poolAddress)
      .getReserveData(vault.asset())
      .variableDebtTokenAddress;
    ICreditDelegationToken variableDebtToken = ICreditDelegationToken(variableDebtTokenAddress);
    baseAsset.approve(address(vault), 10000e18); // Approve the vault to use collateral
    collateralAsset.approve(address(vault), 10000e18); // Approve the vault to use collateral
    collateralAsset.approve(address(poolAddress), 1000e18);
    variableDebtToken.approveDelegation(address(vault), 100e18);

    IPool(poolAddress).supply(address(collateralAsset), 1e18, bob, 0);
    IPool(poolAddress).setUserUseReserveAsCollateral(address(collateralAsset), true);
  }

  function testBorrow() public {
    initialBorrowPrep();

    vm.startPrank(bob);
    // Borrowing from the pool
    vault.borrow(address(collateralAsset), 50e18, 20e18, poolAddress, bob, false); // Borrow 100e18
    // Add assertions to check the state after borrowing
    assertEq(
      baseAsset.balanceOf(bob),
      920e18,
      'Bob should not have less than 920e18 asset after borrow'
    );
  }

  function testBorrowReceiveShares() public {
    initialBorrowPrep();
    uint assetBefore = vault.totalAssets();
    uint balanceBefore = vault.balanceOf(bob);

    // Borrowing from the pool
    vm.startPrank(bob);
    vault.borrow(address(collateralAsset), 50e18, 20e18, poolAddress, bob, true); // Borrow 100e18
    // Add assertions to check the state after borrowing
    assertEq(
      vault.totalAssets(),
      assetBefore + 20e18,
      'Total assets should reflect the new borrowed asset'
    );
    assert(vault.balanceOf(bob) > balanceBefore);
  }

  function testRepay() public {
    testBorrow();

    // Repay the borrowed amount
    vault.repay(20e18, poolAddress, bob); // Repay 100e18
    // Add assertions to check the state after repayment
    // For example, check the balance of the vault or the borrowed amount in the pool
  }

  function testRepayWithShares() public {
    testBorrow();

    // Repay using shares
    uint256 sharesToRepay = vault.simulateWithdrawal(20e18); // Simulate how many shares are needed to repay
    vault.repayWithShares(sharesToRepay, poolAddress, bob); // Repay 100e18
    // Add assertions to check the state after repayment with shares
    // For example, check the balance of the vault or the borrowed amount in the pool
  }

  function testAccrueFees() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 5000, poolAddress); // 50%

    address asset = vault.asset();
    console.log(asset);

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 100e18);
    vault.deposit(100e18, bob);
    // vault.accrueFees();

    // Check if fees were accrued correctly
    // This will depend on your implementation of fee accrual
  }

  function testSetMaxDeposit() public {
    vm.startPrank(owner);
    vault.setMaxDeposit(2000e18);
    assertEq(vault.maxDeposit(address(0)), 2000e18, 'Max deposit should be updated');
  }

  function testSetMaxWithdrawal() public {
    vm.startPrank(owner);
    vault.setMaxWithdrawal(1000e18);
    assertEq(vault.maxWithdrawal(address(0)), 1000e18, 'Max withdrawal should be updated');
  }

  function testSetFeeRecipient() public {
    vm.startPrank(owner);
    vault.setFeeRecipient(owner);
    assertEq(vault.feeRecipient(), owner, 'Fee recipient should be updated');
  }

  function testWithdrawFees() public {
    testWithdraw(); //gen fees
    vm.startPrank(owner);
    vault.setFeeRecipient(owner);
    uint256 initialBalance = baseAsset.balanceOf(owner);
    vault.withdrawFees();

    assertTrue(
      baseAsset.balanceOf(owner) > initialBalance,
      'Fee recipient should have received fees'
    );
  }

  function testRequestWithdrawal() public {
    vm.startPrank(curator);
    vault.addMysticPool(address(baseAsset), MOCK_PRICE_FEED, 1000, poolAddress); // 10%

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 100e18);
    vault.deposit(100e18, bob);
    vault.requestWithdrawal(50e18);
    (, uint256 shares, ) = vault.withdrawalRequests(bob);
    assertEq(shares, 50e18, 'Withdrawal request should be recorded');
  }

  function testSimulateWithdrawal() public {
    uint256 shares = vault.simulateWithdrawal(100e18);
    assertTrue(shares > 0, 'Simulated withdrawal should return shares');
  }

  function testSimulateSupply() public {
    uint256 shares = vault.simulateSupply(100e18);
    assertTrue(shares > 0, 'Simulated supply should return shares');
  }
}
