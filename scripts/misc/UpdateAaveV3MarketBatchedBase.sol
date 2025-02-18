// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {DeployUtils} from '../../src/deployments/contracts/utilities/DeployUtils.sol';
import {AaveV3BatchOrchestration} from '../../src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {DefaultMarketInput} from '../../src/deployments/inputs/DefaultMarketInput.sol';

contract UpdateAaveV3MarketBatchedBase is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    Roles memory roles;
    MarketConfig memory config;
    SubMarketConfig memory subConfig;
    DeployFlags memory flags;
    MarketReport memory report;

    console.log('Aave V3 Batch Update');
    console.log('sender', msg.sender);

    (roles, config, subConfig, flags, report) = _getMarketInput(msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);
    console.log(report.poolAddressesProvider);
    AaveV3BatchOrchestration.updateAaveV3(msg.sender, roles, config, subConfig, flags, report);
    vm.stopBroadcast();
  }
}
