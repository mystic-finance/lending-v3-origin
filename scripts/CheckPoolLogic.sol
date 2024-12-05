// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {AaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {L2PoolInstance} from 'src/core/instances/L2PoolInstance.sol';

abstract contract CheckPoolLogic is Script {
  using stdJson for string;

  function run() external {
    console.log('Aave Check Pool Logic');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    vm.startBroadcast(deployerPrivateKey);
    address pool = 0xd7ecf5312aa4FE7ddcAAFba779494fBC5f5f459A;

    uint reserves = L2PoolInstance(pool).MAX_NUMBER_RESERVES();
    address poolLogic = L2PoolInstance(pool).getPoolLogic();
    address supplyLogic = L2PoolInstance(pool).getSupplyLogic();
    address liqLogic = L2PoolInstance(pool).getLiquidationLogic();
    address emodeLogic = L2PoolInstance(pool).getEModeLogic();
    address bridgeLogic = L2PoolInstance(pool).getBridgeLogic();
    address borrowLogic = L2PoolInstance(pool).getBorrowLogic();
    address flashLoanLogic = L2PoolInstance(pool).getFlashLoanLogic();

    console.log('pool, supply', poolLogic, supplyLogic);
    console.log('liq, emode', liqLogic, emodeLogic);
    console.log('bridge, borrow', bridgeLogic, borrowLogic);
    console.log('flashloan', flashLoanLogic, reserves);

    vm.stopBroadcast();
  }
}
