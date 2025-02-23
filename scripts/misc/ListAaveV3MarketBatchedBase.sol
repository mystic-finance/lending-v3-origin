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
    MarketConfig memory oldConfig;

    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    address debtAsset = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1; //usdc
    address collateralAsset = 0x4632403a83fb736Ab2c76b4C32FAc9F81e2CfcE2; //rwa token (test is usdt)

    (config) = _listAsset(msg.sender, debtAsset, collateralAsset);
    (roles, oldConfig, subConfig, , ) = _getMarketInput(msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);
    // address uipd = AaveV3BatchOrchestration.deployUIPoolDatProvider(
    //   oldConfig.networkBaseTokenPriceInUsdProxyAggregator,
    //   oldConfig.marketReferenceCurrencyPriceInUsdProxyAggregator
    // );
    // console.log(uipd);
    AaveV3BatchOrchestration.upgradeAssetAaveV3(config, subConfig);
    // AaveV3BatchOrchestration.updateAssetPairAaveV3(config, subConfig);
    vm.stopBroadcast();

    // Write market deployment JSON report at /reports
    // IMetadataReporter metadataReporter = IMetadataReporter(
    //   _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    // );
    // metadataReporter.writeJsonReportMarket(report);
  }
}
