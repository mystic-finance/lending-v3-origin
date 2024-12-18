// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {DeployUtils} from 'src/deployments/contracts/utilities/DeployUtils.sol';
// import {AaveV3BatchOrchestration} from 'src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {AaveV3Flashloaner} from 'src/core/contracts/protocol/strategies/Flashloan/AaveFlashLoan.sol';
import {AmbientSwap} from 'src/core/contracts/protocol/strategies/Swap/AmbientSwapper.sol';
import {FlashLoanController} from 'src/core/contracts/protocol/strategies/FlashLoanController.sol';
import {SwapController} from 'src/core/contracts/protocol/strategies/SwapController.sol';

import {AdvancedLoopStrategy} from 'src/core/contracts/protocol/strategies/LoopStrategy.sol';
import {LeveragedBorrowingVault} from 'src/core/contracts/protocol/strategies/LeverageStrategy.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployStrategies is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address lendingPool = vm.envAddress('LENDING_POOL');
    address poolProvider = vm.envAddress('POOL_PROVIDER');
    address ambientSwap = vm.envAddress('AMBIENT_SWAP');

    vm.startBroadcast(deployerPrivateKey);

    // AaveV3BatchOrchestration.updateProviderRegistry(
    //   report.poolAddressesProviderRegistry,
    //   0x1E4aC9797E50bdb9706df99a45dB6afaff212239,
    //   config.providerId
    // );
    AmbientSwap ambientSwapper = new AmbientSwap(ambientSwap);
    AaveV3Flashloaner flashLoaner = new AaveV3Flashloaner(poolProvider);

    SwapController swapController = new SwapController(address(ambientSwapper));
    FlashLoanController flashloanController = new FlashLoanController(address(flashLoaner));

    AdvancedLoopStrategy loopStrategy = new AdvancedLoopStrategy(
      msg.sender,
      lendingPool,
      address(swapController),
      3000
    );
    LeveragedBorrowingVault leverageStrategy = new LeveragedBorrowingVault(
      lendingPool,
      address(swapController),
      address(flashloanController)
    );
    console.log('done');

    console.log('ambientSwapper', address(ambientSwapper));
    console.log('flashLoaner', address(flashLoaner));
    console.log('swapController', address(swapController));
    console.log('flashloanController', address(flashloanController));
    console.log('loopStrategy', address(loopStrategy));
    console.log('leverageStrategy', address(leverageStrategy));
    vm.stopBroadcast();

    // Write market deployment JSON report at /reports
    // IMetadataReporter metadataReporter = IMetadataReporter(
    //   _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    // );
    // metadataReporter.writeJsonReportMarket(report);
  }
}
// 0x783fDF6b9494e6e9DAcFF1f938904Fc47642271F - partial,  0x738eFcb730050f508B6778D49024A7Cd1481B36F - full
