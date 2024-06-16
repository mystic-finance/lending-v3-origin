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

abstract contract ListAaveV3MarketBatchedBase is DeployUtils, MarketInput, Script {
  using stdJson for string;

  function run() external {
    Roles memory roles;
    ListingConfig memory config;
    SubMarketConfig memory subConfig;
    MarketReport memory report;

    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    address debtAsset = 0x07b184FFDfBC2BDfa0B19a8143aCF3C95896Dd93; //usdc
    address collateralAsset = 0xEf8A0681503552a335223d8305824413Fb2C5666; //rwa token (test is usdt)

    (config) = _listAsset(msg.sender, debtAsset, collateralAsset);
    (roles, , subConfig, , ) = _getMarketInput(msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);
    AaveV3BatchOrchestration.listAssetPairAaveV3(config, subConfig);
    vm.stopBroadcast();

    // Write market deployment JSON report at /reports
    // IMetadataReporter metadataReporter = IMetadataReporter(
    //   _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    // );
    // metadataReporter.writeJsonReportMarket(report);
  }
}
