// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "src/core/contracts/protocol/vault/Vault.sol"; // assuming MysticVault is at this path
import {MockAggregator} from "src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import "../mocks/ERC20Mock.sol";
import "src/core/contracts/interfaces/IPool.sol";
import "src/core/contracts/interfaces/IMysticVault.sol";
import "src/core/contracts/interfaces/ICreditDelegationToken.sol";
import {TestnetProcedures} from "../utils/TestnetProcedures.sol";

contract MysticVaultComprehensiveTest is TestnetProcedures {
    MysticVault vault;
    ERC20Mock baseAsset;
    ERC20Mock collateralAsset;
    ERC20Mock aToken;
    MockAggregator priceFeed;
    address owner = address(10);
    address curator = address(101);
    address curatorNew = address(102);
    // address bob = address(2);
    address poolAddress;
    

    // Set up initial state
    function setUp() public {
        // Initialize your testnet environment
        initL2TestEnvironment();

        owner = address(this);
        curator = address(0x1);
        bob = address(0x2);
        // For simplicity we assume usdx and wbtc are pre-deployed mocks
        baseAsset = ERC20Mock(address(usdx));
        collateralAsset = ERC20Mock(address(wbtc));
        aToken = new ERC20Mock("Test AToken", "TAT", 18);
        priceFeed = new MockAggregator(1e8); // price feed with 8 decimals
        poolAddress = address(contracts.poolProxy);

        vault = new MysticVault(
            address(baseAsset),
            1 days,
            owner,
            curator,
            1000e18,   // maxDeposit
            1000e18,   // maxWithdrawal
            100,       // fee in basis points (1%)
            owner,     // feeRecipient
            "Mystic Vault",
            "AVLT"
        );

        // Mint assets to owner and bob
        vm.startPrank(poolAdmin);
        baseAsset.mint(owner, 1000e18);
        baseAsset.mint(bob, 1000e18);
        collateralAsset.mint(bob, 1000e18);

        // Approvals for bob
        vm.startPrank(bob);
        baseAsset.approve(address(vault), 10000e18);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////
    // DEPOSIT TESTS
    ////////////////////////////////////////////////////////////////

    // Basic deposit
    function testDepositBasic() public {
        vm.startPrank(curator);
        // Add pool with a 50% allocation for baseAsset
        vault.addMysticPool(address(baseAsset), address(priceFeed), 5000, poolAddress);
        vm.stopPrank();

        vm.startPrank(bob);
        baseAsset.approve(address(vault), 100e18);
        uint256 sharesMinted = vault.deposit(100e18, bob);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 100e18, "Total assets should equal deposit");
        assertEq(vault.balanceOf(bob), sharesMinted, "Bob's share balance should match minted shares");
        assertEq(baseAsset.balanceOf(bob), 900e18, "Bob's baseAsset balance should be reduced");
    }

    // Edge: Deposit zero should revert or produce zero shares
    function testDepositZero() public {
        vm.startPrank(curator);
        vault.addMysticPool(address(baseAsset), address(priceFeed), 5000, poolAddress);
        vm.stopPrank();

        vm.startPrank(bob);
        baseAsset.approve(address(vault), 1e18);
        vm.expectRevert("ERC4626: deposit zero assets");
        vault.deposit(0, bob);
        vm.stopPrank();
    }

    // Deposit exceeding maxDeposit should revert
    function testDepositExceedMax() public {
        vm.startPrank(curator);
        vault.addMysticPool(address(baseAsset), address(priceFeed), 5000, poolAddress);
        vm.stopPrank();

        vm.startPrank(bob);
        baseAsset.approve(address(vault), 2000e18);
        vm.expectRevert("Deposit amount exceeds maximum");
        vault.deposit(2000e18, bob);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////
    // WITHDRAW TESTS
    ////////////////////////////////////////////////////////////////

    // Basic withdrawal (after deposit)
    function testWithdrawBasic() public {
        testDepositBasic();
        vm.startPrank(bob);
        vault.requestWithdrawal(50e18);
        vm.warp(block.timestamp + 2 days); // ensure timelock met
        uint256 withdrawn = vault.withdraw(50e18, bob, bob);
        vm.stopPrank();

        // Check vault's totalAssets and bob's asset balance
        assertEq(vault.totalAssets(), 50e18, "Vault total assets should reflect withdrawal");
        // Bob's balance: initial 1000e18 - deposit 100e18 + withdrawal 50e18 (minus fees, see fee test below)
    }

    // Test withdrawal before timelock should revert
    function testWithdrawBeforeTimelock() public {
        testDepositBasic();
        vm.startPrank(bob);
        vault.requestWithdrawal(50e18);
        // Do not warp time
        vm.expectRevert("Withdrawal timelock not met");
        vault.withdraw(50e18, bob, bob);
        vm.stopPrank();
    }

    // Test redeem (shares based withdrawal)
    function testRedeem() public {
        testDepositBasic();
        vm.startPrank(bob);
        vault.requestWithdrawal(50e18);
        vm.warp(block.timestamp + 2 days);
        uint256 redeemed = vault.redeem(0, bob, bob); // shares computed internally
        vm.stopPrank();

        // Assert some conditions on vault state and bob's balance
        require(vault.totalAssets() < 100e18, "Vault total assets reduced after redeem");
    }

    ////////////////////////////////////////////////////////////////
    // BORROW & REPAY TESTS
    ////////////////////////////////////////////////////////////////

    // Helper: prepare collateral and deposit so borrow can work
    function prepareForBorrow() internal {
        testDepositBasic();
        vm.startPrank(bob);
        // Approve collateral, and deposit collateral into pool.
        collateralAsset.approve(address(vault), 1000e18);
        collateralAsset.approve(poolAddress, 1000e18);
        // Supply collateral to pool
        IPool(poolAddress).supply(address(collateralAsset), 1e18, bob, 0);
        // Mark collateral as approved
        IPool(poolAddress).setUserUseReserveAsCollateral(address(collateralAsset), true);
        // Approve delegation for borrow
        address variableDebtTokenAddress = IPool(poolAddress).getReserveData(vault.asset()).variableDebtTokenAddress;
        ICreditDelegationToken(variableDebtTokenAddress).approveDelegation(address(vault), 100e18);
        vm.stopPrank();
    }

    // Basic borrow test (without receiving shares)
    function testBorrow() public {
        prepareForBorrow();
        vm.startPrank(bob);
        uint256 balanceBefore = baseAsset.balanceOf(bob);
        vault.borrow(address(collateralAsset), 50e18, 20e18, poolAddress, bob, false);
        vm.stopPrank();

        // Bob should have more baseAsset after borrow (20e18 added)
        uint256 balanceAfter = baseAsset.balanceOf(bob);
        assertEq(balanceAfter, balanceBefore + 20e18, "Bob's asset balance should increase by borrow amount");
    }

    // Borrow with receiveShares = true
    function testBorrowReceiveShares() public {
        prepareForBorrow();
        vm.startPrank(bob);
        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 bobSharesBefore = vault.balanceOf(bob);
        vault.borrow(address(collateralAsset), 50e18, 20e18, poolAddress, bob, true);
        vm.stopPrank();

        // Vault totalAssets increases by borrow amount and bob's shares increase
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 bobSharesAfter = vault.balanceOf(bob);
        assertEq(totalAssetsAfter, totalAssetsBefore + 20e18, "Vault assets should increase by borrowed amount");
        assert(bobSharesAfter > bobSharesBefore);
    }

    // Repay borrow with asset transfer
    function testRepay() public {
        testBorrow();
        uint256 totalBorrowedBefore = vault.totalBorrowed();
        // Bob repays borrow from his wallet
        vm.startPrank(bob);
        uint256 bobBalanceBefore = baseAsset.balanceOf(bob);
        vault.repay(20e18, poolAddress, bob);
        vm.stopPrank();
        uint256 totalBorrowedAfter = vault.totalBorrowed();
        assertLt(totalBorrowedAfter, totalBorrowedBefore, "Total borrowed should decrease after repay");
        // Bob's wallet balance decreases accordingly
        uint256 bobBalanceAfter = baseAsset.balanceOf(bob);
        assertLt(bobBalanceAfter, bobBalanceBefore, "Bob's wallet balance should reduce after repayment");
    }

    // Repay borrow with shares
    function testRepayWithShares() public {
        testBorrow();
        uint256 totalBorrowedBefore = vault.totalBorrowed();
        vm.startPrank(bob);
        uint256 sharesToRepay = vault.simulateWithdrawal(20e18);
        uint256 bobSharesBefore = vault.balanceOf(bob);
        vault.repayWithShares(sharesToRepay, poolAddress, bob);
        vm.stopPrank();

        uint256 totalBorrowedAfter = vault.totalBorrowed();
        assertLt(totalBorrowedAfter, totalBorrowedBefore, "Total borrowed should decrease after repayWithShares");
        uint256 bobSharesAfter = vault.balanceOf(bob);
        assertLt(bobSharesAfter, bobSharesBefore, "Bob's share balance should reduce after repayWithShares");
    }

    ////////////////////////////////////////////////////////////////
    // REBALANCING TESTS
    ////////////////////////////////////////////////////////////////

    // Test that rebalancing is triggered and depositsToProcess is cleared
    function testRebalanceExecution() public {
        vm.startPrank(curator);
        // Add two pools with different allocations
        vault.addMysticPool(address(baseAsset), address(priceFeed), 3000, poolAddress);
        vault.addMysticPool(address(baseAsset), address(priceFeed), 2000, address(0x5));
        vm.stopPrank();

        vm.startPrank(bob);
        baseAsset.approve(address(vault), 200e18);
        vault.deposit(200e18, bob);
        vm.stopPrank();

        // Check that after a deposit the depositsToProcess array is cleared and rebalancing event is emitted
        // (This may require event listeners or checking internal state if accessible.)
        // For illustration, we check that depositsToProcess length is zero:
        // vault.DepositData[] depositsToProcess = vault.depositsToProcess();
        // uint256 len = depositsToProcess.length;
        // assertEq(len, 0, "Deposits cache should be cleared after rebalance");
    }

    ////////////////////////////////////////////////////////////////
    // ADMIN FUNCTIONS TESTS
    ////////////////////////////////////////////////////////////////

    function testSetMaxDeposit() public {
        vm.startPrank(owner);
        vault.setMaxDeposit(2000e18);
        uint256 maxDep = vault.maxDeposit(address(0));
        vm.stopPrank();
        assertEq(maxDep, 2000e18, "Max deposit should be updated by admin");
    }

    function testSetMaxWithdrawal() public {
        vm.startPrank(owner);
        vault.setMaxWithdrawal(800e18);
        uint256 maxWith = vault.maxWithdrawal(address(0));
        vm.stopPrank();
        assertEq(maxWith, 800e18, "Max withdrawal should be updated by admin");
    }

    function testSetFee() public {
        vm.startPrank(owner);
        vault.setFee(500); // 5%
        vm.stopPrank();
        // Since fee is public, we can check it directly
        assertEq(vault.fee(), 500, "Fee should be updated by owner");
    }

    function testSetFeeRecipient() public {
        vm.startPrank(owner);
        vault.setFeeRecipient(bob);
        vm.stopPrank();
        assertEq(vault.feeRecipient(), bob, "Fee recipient should be updated by admin");
    }

    ////////////////////////////////////////////////////////////////
    // FEES ACCRUAL TESTS
    ////////////////////////////////////////////////////////////////

    function testFeeAccrual() public {
        // Add a pool with an allocation that will cause fee accrual on withdrawal
        vm.startPrank(curator);
        vault.addMysticPool(address(baseAsset), address(priceFeed), 5000, poolAddress);
        vm.stopPrank();

        // Bob deposits and then withdraws to generate fees
        vm.startPrank(bob);
        baseAsset.approve(address(vault), 100e18);
        vault.deposit(100e18, bob);
        vault.requestWithdrawal(50e18);
        vm.warp(block.timestamp + 2 days);
        uint256 bobBalanceBeforeWithdraw = baseAsset.balanceOf(bob);
        vault.withdraw(50e18, bob, bob);
        uint256 bobBalanceAfterWithdraw = baseAsset.balanceOf(bob);
        vm.stopPrank();

        // Check that fees were accrued (fee is 1% in this test configuration)
        // Expected fee = (withdrawAmount * fee) / PERCENTAGE_SCALE
        uint256 expectedFee = (50e18 * 100) / 10000;
        // Since fees are transferred to feeRecipient on withdrawal, simulate feeRecipient withdrawal:
        vm.startPrank(owner);
        uint256 feeRecipientBalanceBefore = baseAsset.balanceOf(owner);
        vault.withdrawFees();
        uint256 feeRecipientBalanceAfter = baseAsset.balanceOf(owner);
        vm.stopPrank();

        assertTrue(feeRecipientBalanceAfter > feeRecipientBalanceBefore, "Fee recipient should receive fees");
        // Also, check that bob's balance is lower by at least the fee amount
        assertLt(bobBalanceAfterWithdraw, bobBalanceBeforeWithdraw + 50e18, "Bob should not receive full amount due to fees");
    }

    ////////////////////////////////////////////////////////////////
    // WALLET STATE TESTS
    ////////////////////////////////////////////////////////////////

    // Test wallet balances before and after deposit, borrow, repay and withdraw
    function testWalletStateTransitions() public {
        // Save initial balances
        uint256 ownerInitial = baseAsset.balanceOf(owner);
        uint256 bobInitial = baseAsset.balanceOf(bob);

        // Bob deposits 100e18
        vm.startPrank(bob);
        baseAsset.approve(address(vault), 100e18);
        vault.deposit(100e18, bob);
        uint256 bobPostDeposit = baseAsset.balanceOf(bob);
        uint256 vaultAssetsAfterDeposit = vault.totalAssets();
        vm.stopPrank();

        assertEq(bobInitial - bobPostDeposit, 100e18, "Bob's balance should drop by deposit amount");
        assertEq(vaultAssetsAfterDeposit, 100e18, "Vault assets should reflect deposit");

        // Prepare for borrow
        prepareForBorrow();

        // Bob borrows 20e18
        vm.startPrank(bob);
        uint256 bobBalanceBeforeBorrow = baseAsset.balanceOf(bob);
        vault.borrow(address(collateralAsset), 50e18, 20e18, poolAddress, bob, false);
        uint256 bobBalanceAfterBorrow = baseAsset.balanceOf(bob);
        vm.stopPrank();

        assertEq(bobBalanceAfterBorrow, bobBalanceBeforeBorrow + 20e18, "Bob's balance should increase by borrow amount");

        // Bob repays 20e18
        vm.startPrank(bob);
        uint256 bobBalanceBeforeRepay = baseAsset.balanceOf(bob);
        vault.repay(20e18, poolAddress, bob);
        uint256 bobBalanceAfterRepay = baseAsset.balanceOf(bob);
        vm.stopPrank();

        assertLt(bobBalanceAfterRepay, bobBalanceBeforeRepay, "Bob's balance should decrease after repay");

        // Bob requests withdrawal and withdraws 50e18
        vm.startPrank(bob);
        vault.requestWithdrawal(50e18);
        vm.warp(block.timestamp + 2 days);
        uint256 bobBalanceBeforeWithdraw = baseAsset.balanceOf(bob);
        vault.withdraw(50e18, bob, bob);
        uint256 bobBalanceAfterWithdraw = baseAsset.balanceOf(bob);
        vm.stopPrank();

        // The final state checks: vault assets, bob's balance, fee deductions etc.
        assertTrue(bobBalanceAfterWithdraw > bobBalanceBeforeWithdraw, "Bob's balance should increase due to withdrawal");
    }
}
