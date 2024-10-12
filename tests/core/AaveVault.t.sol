// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import 'src/core/contracts/protocol/vault/AaveVault.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import '../mocks/ERC20Mock.sol'; // Mock ERC20 for testing
import '../../src/core/contracts/interfaces/IPool.sol';
import '../../src/core/contracts/dependencies/chainlink/AggregatorInterface.sol';
import '../../src/core/contracts/interfaces/IAaveVault.sol';

contract AaveVaultTest is Test {
  AaveVault vault;
  ERC20Mock baseAsset;
  ERC20Mock aToken;
  address MOCK_PRICE_FEED;
  address owner = address(10);
  address curator = address(101);
  address curatorNew = address(102);
  address bob = address(1567);

  function setUp() public {
    owner = address(this);
    curator = address(0x1);
    bob = address(0x2);
    baseAsset = new ERC20Mock('Base Asset', 'BA', 18);
    aToken = new ERC20Mock('Test AToken', 'TAT', 18);
    MOCK_PRICE_FEED = address(new MockAggregator(1e8));
    vault = new AaveVault(
      address(baseAsset),
      1 days,
      owner,
      curator,
      1000e18,
      500e18,
      100, // 1%
      owner,
      'Aave Vault',
      'AVLT'
    );
    baseAsset.mint(owner, 1000e18); // Mint some base asset for testing
    baseAsset.mint(bob, 1000e18); // Mint some base asset for testing
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

  // function testAddAavePool() public {
  //   vm.startPrank(curator);
  //   vault.addAavePool(address(0x3));
  //   // assertTrue(vault._isAavePoolAdded(address(0x3)), 'Aave pool should be added');
  // }

  // function testAddMultipleAavePool() public {
  //   vm.startPrank(curator);
  //   vault.addAavePool(address(0x3));
  //   vault.addAavePool(address(0x5));
  //   vault.addAavePool(address(0x8));
  //   // assertTrue(vault._isAavePoolAdded(address(0x3)), 'Aave pool should be added');
  // }

  function testAddAssetAllocation() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(address(0x3), address(baseAsset));

    assertEq(allocationPercentage, 1000, 'Asset allocation should be added');
    assertEq(
      vault.poolAssets(address(0x3), 0),
      address(baseAsset),
      'Asset should be in pool assets'
    );
  }

  function testAddAssetAllocationBatch() public {
    vm.startPrank(curator);

    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 5000, address(0x5)); // 10%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(address(0x3), address(baseAsset));

    assertEq(allocationPercentage, 1000, 'Asset allocation should be added');

    (, , , uint256 allocationPercentage2) = vault.assetAllocations(
      address(0x5),
      address(baseAsset)
    );

    assertEq(allocationPercentage2, 5000, 'Asset allocation should be added');
    assertEq(
      vault.poolAssets(address(0x3), 0),
      address(baseAsset),
      'Asset should be in pool assets'
    );
  }

  function testUpdateAssetAllocation() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%
    vault.updateAssetAllocation(address(baseAsset), address(0x3), 500); // Update to 5%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(address(0x3), address(baseAsset));

    assertEq(allocationPercentage, 500, 'Asset allocation should be updated');
  }

  function testReallocate() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%
    vault.reallocate(address(baseAsset), address(0x3), 500); // Reallocate to 5%
    (, , , uint256 allocationPercentage) = vault.assetAllocations(address(0x3), address(baseAsset));

    assertEq(allocationPercentage, 500, 'Asset allocation should be reallocated');
  }

  function testDeposit() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 100e18);
    vault.deposit(100e18, bob);
    address asset = vault.asset();
    console.log(asset);

    assertEq(vault.totalAssets(), 100e18, 'Total assets should reflect the deposit');
    assertEq(baseAsset.balanceOf(bob), 900e18, 'Owner should have 900 ether left');
  }

  function testWithdraw() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%

    vm.startPrank(bob);
    baseAsset.approve(address(vault), 100e18);
    vault.deposit(100e18, bob);
    vault.requestWithdrawal(50e18);
    uint fee = (100 * 50e18) / 10000;
    uint remaining = 100e18 - 50e18 + fee;

    vm.warp(block.timestamp + 1 days); // Move time forward to meet timelock
    vault.withdraw(50e18, bob, bob);

    assertEq(vault.totalAssets(), remaining, 'Total assets should reflect the withdrawal');
    assertEq(
      baseAsset.balanceOf(bob),
      950e18 - fee,
      'Bob should less than 950 ether after withdrawal'
    );
  }

  function testAccrueFees() public {
    vm.startPrank(curator);
    vault.addAavePool(address(baseAsset), address(aToken), MOCK_PRICE_FEED, 1000, address(0x3)); // 10%

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
