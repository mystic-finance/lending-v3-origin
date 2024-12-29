// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {DeployUtils} from 'src/deployments/contracts/utilities/DeployUtils.sol';
// import {AaveV3BatchOrchestration} from 'src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {WrappedTokenGatewayV3} from 'src/periphery/contracts/misc/WrappedTokenGatewayV3.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployGateway is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    // address lendingPool = vm.envAddress('LENDING_POOL');

    vm.startBroadcast(deployerPrivateKey);

    WrappedTokenGatewayV3 tokenGateway = new WrappedTokenGatewayV3(
      0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74,
      msg.sender,
      IPool(0xd7ecf5312aa4FE7ddcAAFba779494fBC5f5f459A)
    );

    console.log('tokenGateway', address(tokenGateway));
    vm.stopBroadcast();
  }
}
// mainnet - 0xeed79850EBfA660132b3619f5388B9f57859D71D
// devnet - 0x9811870984C7B8f1a5548dF80223368ECde24f26
