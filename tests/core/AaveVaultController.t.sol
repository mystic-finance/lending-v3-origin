// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import {MysticVaultController} from 'src/core/contracts/protocol/vault/VaultController.sol';
import {MysticVault} from 'src/core/contracts/protocol/vault/Vault.sol';
import '../mocks/ERC20Mock.sol';
import '../../src/core/contracts/interfaces/IPool.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {MockAggregator} from 'src/core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';

contract MysticVaultControllerTest is TestnetProcedures {
  MysticVaultController controller;
  ERC20Mock baseToken1;
  ERC20Mock baseToken2;
  MysticVault vault1;
  MysticVault vault2;
  address owner;
  address curator;
  address poolAddress;
  address MOCK_PRICE_FEED;

  function setUp() public {
    initL2TestEnvironment();

    owner = address(this);
    curator = address(0x1);
    bob = address(0x2);
    MOCK_PRICE_FEED = address(new MockAggregator(1e8));

    // Deploy mock tokens
    baseToken1 = ERC20Mock(address(usdx));
    baseToken2 = ERC20Mock(address(wbtc));

    // Create vault controller
    controller = new MysticVaultController();

    // Setup pool address (mock)
    poolAddress = address(contracts.poolProxy);

    // Create vaults
    vault1 = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100, // 1%
      owner,
      'Vault 1',
      'VLT1'
    );

    vault2 = new MysticVault(
      address(baseToken2),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100, // 1%
      owner,
      'Vault 2',
      'VLT2'
    );

    // Setup roles and add vaults
    vm.startPrank(owner);
    controller.addCurator(curator);

    vm.startPrank(curator);
    controller.addVault(address(vault1));
    controller.addVault(address(vault2));

    vm.startPrank(poolAdmin);
    baseToken1.mint(bob, 10000e18); // Mint some base asset for testing
    baseToken2.mint(bob, 10000e18); // Mint some base asset for testing
  }

  function testAddVault() public {
    // Vault setup is done in setUp, so we just check the state
    address[] memory allVaults = controller.getAllVaults();
    assertEq(allVaults.length, 2, 'Should have 2 vaults');

    address[] memory token1Vaults = controller.getVaultsForToken(address(baseToken1));
    assertEq(token1Vaults.length, 1, 'Should have 1 vault for token1');
    assertEq(token1Vaults[0], address(vault1), 'Vault1 should be registered for token1');

    address[] memory token2Vaults = controller.getVaultsForToken(address(baseToken2));
    assertEq(token2Vaults.length, 1, 'Should have 1 vault for token2');
    assertEq(token2Vaults[0], address(vault2), 'Vault2 should be registered for token2');
  }

  function testSetVaultActivation() public {
    vm.startPrank(curator);

    // Initially vaults are active
    (, , bool isActive) = controller.vaultRegistry(address(vault1));
    assertTrue(isActive, 'Vault1 should be active initially');

    // Deactivate vault
    controller.setVaultActivation(address(vault1), false);

    // Check vault is now inactive
    (, , isActive) = controller.vaultRegistry(address(vault1));
    assertFalse(isActive, 'Vault1 should be inactive');

    // Try to deposit to inactive vault should fail
    vm.startPrank(bob);
    baseToken1.approve(address(controller), 100e18);
    vm.expectRevert('Vault is not active');
    controller.depositToSpecificVault(address(baseToken1), 100e18, address(vault1));
  }

  function testDepositToSpecificVault() public {
    vm.startPrank(curator);
    vault1.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1000, poolAddress); // 10%

    (, address aToken, , uint256 allocationPercentage) = vault1.assetAllocations(
      poolAddress,
      address(baseToken1)
    );
    console.log(aToken, allocationPercentage);

    vm.startPrank(bob);
    baseToken1.approve(address(controller), 100e18);

    uint256 initialBalance = baseToken1.balanceOf(bob);
    controller.depositToSpecificVault(address(baseToken1), 50e18, address(vault1));

    // Check balances and vault state
    assertEq(baseToken1.balanceOf(bob), initialBalance - 50e18, 'Bob should have less tokens');
    assertEq(vault1.balanceOf(bob), 50e18, 'Bob should have vault shares');
  }

  function testDepositTokens() public {
    vm.startPrank(curator);
    vault1.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    vault2.addMysticPool(address(baseToken2), MOCK_PRICE_FEED, 1000, poolAddress); // 10%

    // Create another vault for baseToken1
    MysticVault vault3 = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100, // 1%
      owner,
      'Vault 3',
      'VLT3'
    );

    vm.startPrank(curator);
    controller.addVault(address(vault3));
    vault3.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1500, poolAddress); // 10%

    // Prepare deposit
    vm.startPrank(bob);
    baseToken1.approve(address(controller), 300e18);
    // Deposit tokens
    controller.depositTokens(address(baseToken1), 300e18);

    // Check split deposits
    assertTrue(vault1.balanceOf(bob) > 0, 'Vault1 should receive deposit');
    assertTrue(vault3.balanceOf(bob) > 0, 'Vault3 should receive deposit');

    // Total deposited should be close to 300e18 (accounting for small rounding differences)
    uint256 totalDeposited = vault1.balanceOf(bob) + vault3.balanceOf(bob);
    assertTrue(
      totalDeposited >= 299e18 && totalDeposited <= 300e18,
      'Total deposited should be close to 300'
    );
  }

  function testAddAndRemoveCurator() public {
    address newCurator = address(0x3);

    // Only admin can add/remove curators
    vm.startPrank(owner);

    // Add new curator
    controller.addCurator(newCurator);
    assertTrue(
      controller.hasRole(controller.CURATOR_ROLE(), newCurator),
      'New curator should be added'
    );

    // Remove curator
    controller.removeCurator(newCurator);
    assertFalse(
      controller.hasRole(controller.CURATOR_ROLE(), newCurator),
      'Curator should be removed'
    );
  }

  function testGetSuitableVaultsForToken() public {
    // Create a vault for a different token
    ERC20Mock uniqueToken = new ERC20Mock('Unique Token', 'UNQ', 18);
    MysticVault uniqueVault = new MysticVault(
      address(uniqueToken),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100, // 1%
      owner,
      'Unique Vault',
      'UVLT'
    );

    vm.startPrank(curator);
    controller.addVault(address(uniqueVault));
    uniqueVault.addMysticPool(address(uniqueToken), MOCK_PRICE_FEED, 1000, poolAddress); // 10%

    // Check suitable vaults for baseToken1
    address[] memory suitableVaults = controller.getSuitableVaultsForToken(address(baseToken1));
    assertEq(suitableVaults.length, 1, 'Should have 1 suitable vaults for baseToken1');

    // Check suitable vaults for unique token
    suitableVaults = controller.getSuitableVaultsForToken(address(uniqueToken));
    assertEq(suitableVaults.length, 1, 'Should have 1 suitable vault for unique token');
    assertEq(suitableVaults[0], address(uniqueVault), 'Unique vault should be returned');
  }

  // Access control tests
  function testOnlyAdminCanAddRemoveCurator() public {
    address randomUser = address(0x999);

    // Try to add curator as non-admin
    vm.startPrank(randomUser);
    vm.expectRevert(); // Should revert due to lack of DEFAULT_ADMIN_ROLE
    controller.addCurator(randomUser);

    vm.startPrank(owner);
    controller.addCurator(randomUser);

    // Try to remove curator as non-admin
    vm.startPrank(randomUser);
    vm.expectRevert(); // Should revert due to lack of DEFAULT_ADMIN_ROLE
    controller.removeCurator(randomUser);
  }

  function testVaultRankingAndSelection() public {
    vm.startPrank(curator);
    vault1.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    vault2.addMysticPool(address(baseToken2), MOCK_PRICE_FEED, 1000, poolAddress); // 10%

    // Create multiple vaults with different APRs and TVLs
    MysticVault noAPRVault = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100,
      owner,
      'No APR Vault',
      'LAPV'
    );

    MysticVault lowAPRVault = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100,
      owner,
      'Low APR Vault',
      'LAPV'
    );

    MysticVault midAPRVault = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100,
      owner,
      'Mid APR Vault',
      'MAPV'
    );

    MysticVault highAPRVault = new MysticVault(
      address(baseToken1),
      1 days,
      owner,
      curator,
      1000e18,
      1000e18,
      100,
      owner,
      'High APR Vault',
      'HAPV'
    );

    vm.startPrank(curator);
    controller.addVault(address(noAPRVault));
    controller.addVault(address(lowAPRVault));
    controller.addVault(address(midAPRVault));
    controller.addVault(address(highAPRVault));
    noAPRVault.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1000, poolAddress); // 10%
    lowAPRVault.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1200, poolAddress); // 10%
    midAPRVault.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 1400, poolAddress); // 10%
    highAPRVault.addMysticPool(address(baseToken1), MOCK_PRICE_FEED, 3000, poolAddress); // 10%

    // Mock APR and TVL differences
    vm.mockCall(
      address(noAPRVault),
      abi.encodeWithSelector(MysticVault.getAPRs.selector),
      abi.encode(MysticVault.APRData(5, 10))
    );

    vm.mockCall(
      address(lowAPRVault),
      abi.encodeWithSelector(MysticVault.getAPRs.selector),
      abi.encode(MysticVault.APRData(10, 20))
    );

    vm.mockCall(
      address(midAPRVault),
      abi.encodeWithSelector(MysticVault.getAPRs.selector),
      abi.encode(MysticVault.APRData(20, 40))
    );

    vm.mockCall(
      address(highAPRVault),
      abi.encodeWithSelector(MysticVault.getAPRs.selector),
      abi.encode(MysticVault.APRData(50, 100))
    );

    // Simulate different total assets (TVL)
    vm.mockCall(
      address(lowAPRVault),
      abi.encodeWithSelector(MysticVault.totalAssets.selector),
      abi.encode(10e18)
    );

    vm.mockCall(
      address(lowAPRVault),
      abi.encodeWithSelector(MysticVault.totalAssets.selector),
      abi.encode(100e18)
    );

    vm.mockCall(
      address(midAPRVault),
      abi.encodeWithSelector(MysticVault.totalAssets.selector),
      abi.encode(500e18)
    );

    vm.mockCall(
      address(highAPRVault),
      abi.encodeWithSelector(MysticVault.totalAssets.selector),
      abi.encode(1000e18)
    );

    // Prepare deposit
    vm.startPrank(bob);
    baseToken1.approve(address(controller), 1000e18);

    // Deposit tokens
    controller.depositTokens(address(baseToken1), 1000e18);

    // Verify vault selection prioritizes high APR and high TVL
    uint256 highAPRVaultBalance = highAPRVault.balanceOf(bob);
    uint256 midAPRVaultBalance = midAPRVault.balanceOf(bob);
    uint256 lowAPRVaultBalance = lowAPRVault.balanceOf(bob);
    uint256 noAPRVaultBalance = noAPRVault.balanceOf(bob);

    console.log(highAPRVaultBalance, midAPRVaultBalance);
    console.log(lowAPRVaultBalance, noAPRVaultBalance);

    // Validate ranking logic
    assertTrue(highAPRVaultBalance > midAPRVaultBalance, 'High APR vault should get more deposits');
    assertTrue(
      lowAPRVaultBalance > noAPRVaultBalance,
      'Mid APR vault should get more deposits than low APR'
    );

    // Ensure total deposits match
    assertTrue(highAPRVaultBalance > 0);
    assertTrue(midAPRVaultBalance > 0);
    assertTrue(lowAPRVaultBalance > 0);
    assertTrue(noAPRVaultBalance <= 0);
  }
}
