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

abstract contract DeployAaveBundlerBased is DeployUtils, MarketInput, Script {
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
    address pointsProgram = vm.envAddress('POINTS_PROGRAM');
    uint8 task = uint8(vm.envUint('POINTS_TASK_ID'));

    vm.startBroadcast(deployerPrivateKey);

    // AaveV3BatchOrchestration.updateProviderRegistry(
    //   report.poolAddressesProviderRegistry,
    //   0x1E4aC9797E50bdb9706df99a45dB6afaff212239,
    //   config.providerId
    // );
    // address wrapper = AaveV3BatchOrchestration.deployAaveBundler(
    //   config.poolProxy,
    //   pointsProgram,
    //   task
    // );

    // AaveV3BatchOrchestration.testAaveBundler(
    //   0x783fDF6b9494e6e9DAcFF1f938904Fc47642271F,
    //   0x5c1409a46cD113b3A667Db6dF0a8D7bE37ed3BB3,
    //   10000
    // ); 0x738eFcb730050f508B6778D49024A7Cd1481B36F

    // console.log('wrapped', wrapper);
    vm.stopBroadcast();

    // Write market deployment JSON report at /reports
    // IMetadataReporter metadataReporter = IMetadataReporter(
    //   _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    // );
    // metadataReporter.writeJsonReportMarket(report);
  }
}
