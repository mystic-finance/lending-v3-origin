// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {DeployUtils} from 'src/deployments/contracts/utilities/DeployUtils.sol';
import {AaveV3BatchOrchestration} from 'src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {WrappedTokenGatewayV3} from 'src/periphery/contracts/misc/WrappedTokenGatewayV3.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployNewImpl is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    MarketConfig memory config;
    DeployFlags memory flags;

    console.log('Aave V3 New Implementation');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    (, config, , flags, ) = _getMarketInput(msg.sender);

    vm.startBroadcast(deployerPrivateKey);

    bool updated = AaveV3BatchOrchestration.updatePool(
      payable(0xB3E7087077452305436F81391d4948025786e0c8),
      config,
      flags
    );

    console.log('updated', updated);
    vm.stopBroadcast();
  }
}
