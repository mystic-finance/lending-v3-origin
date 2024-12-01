// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {AaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {DeployUtils} from '../../src/deployments/contracts/utilities/DeployUtils.sol';
import {AaveV3BatchOrchestration} from '../../src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {MarketInput} from '../../src/deployments/inputs/MarketInput.sol';

abstract contract DeployAaveVaultBase is DeployUtils, MarketInput, Script {
  using stdJson for string;

  function run() external {
    Roles memory roles;
    ListingConfig memory config;
    SubMarketConfig memory subConfig;
    MarketReport memory report;
    MarketConfig memory oldConfig;

    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    config = _listAsset(msg.sender, address(0), address(0));
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address vaultFactory = vm.envAddress('VAULT_FACTORY');

    if (vaultFactory == address(0)) {
      vm.startBroadcast(deployerPrivateKey);

      (address newVaultFactory, ) = AaveV3BatchOrchestration.deployAaveVaultFactory();
      console.log('vault factory', newVaultFactory);

      vm.stopBroadcast();
    } else {
      uint256 vaultTimelock = vm.envUint('VAULT_TIMELOCK');
      address asset = vm.envAddress('ASSET');
      uint256 maxDeposit = vm.envUint('MAX_DEPOSIT');
      uint256 maxWithdrawal = vm.envUint('MAX_WITHDRAWAL');
      uint256 fee = vm.envUint('VAULT_FEE');
      address feeRecipient = vm.envAddress('VAULT_FEE_RECIPIENT');
      string memory name = vm.envString('VAULT_NAME');
      string memory symbol = vm.envString('VAULT_SYMBOL');
      bytes32 salt = vm.envBytes32('VAULT_SALT');

      vm.startBroadcast(deployerPrivateKey);

      address aaveVault = AaveV3BatchOrchestration.deployAaveVault(
        vaultFactory,
        vaultTimelock,
        asset,
        maxDeposit,
        maxWithdrawal,
        fee,
        feeRecipient,
        name,
        symbol,
        salt
      );
      console.log('mystic vault', aaveVault);

      vm.stopBroadcast();
    }
  }
}
