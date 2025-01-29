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
    AmbientSwap ambientSwapper = new AmbientSwap(ambientSwap, lendingPool);
    AaveV3Flashloaner flashLoaner = new AaveV3Flashloaner(poolProvider);

    SwapController swapController = new SwapController(address(ambientSwapper));
    FlashLoanController flashloanController = new FlashLoanController(address(flashLoaner));

    // SwapController swapController = SwapController(0x0f8d9480ca937441c166E39e2d9f90a7A6031194);
    // swapController.updateSwapper(address(ambientSwapper));

    AdvancedLoopStrategy loopStrategy = new AdvancedLoopStrategy(
      msg.sender,
      lendingPool,
      address(swapController),
      500
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

    // mainnet
    // leverageStrategy.addAllowedBorrowToken(0x3938A812c54304fEffD266C7E2E70B48F9475aD6);
    // leverageStrategy.addAllowedBorrowToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    // leverageStrategy.addAllowedBorrowToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    // leverageStrategy.addAllowedBorrowToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    // leverageStrategy.addAllowedCollateralToken(0x3938A812c54304fEffD266C7E2E70B48F9475aD6);
    // leverageStrategy.addAllowedCollateralToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    // leverageStrategy.addAllowedCollateralToken(0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73);
    // leverageStrategy.addAllowedCollateralToken(0x81537d879ACc8a290a1846635a0cAA908f8ca3a6);

    // devnet
    leverageStrategy.addAllowedBorrowToken(0xe644F07B1316f28a7F134998e021eA9f7135F351);
    leverageStrategy.addAllowedBorrowToken(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74);
    leverageStrategy.addAllowedBorrowToken(0x2413b8C79Ce60045882559f63d308aE3DFE0903d);
    leverageStrategy.addAllowedBorrowToken(0x401eCb1D350407f13ba348573E5630B83638E30D);

    leverageStrategy.addAllowedCollateralToken(0xe644F07B1316f28a7F134998e021eA9f7135F351);
    leverageStrategy.addAllowedCollateralToken(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74);
    leverageStrategy.addAllowedCollateralToken(0x2413b8C79Ce60045882559f63d308aE3DFE0903d);
    leverageStrategy.addAllowedCollateralToken(0x401eCb1D350407f13ba348573E5630B83638E30D);
    vm.stopBroadcast();

    // Write market deployment JSON report at /reports
    // IMetadataReporter metadataReporter = IMetadataReporter(
    //   _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    // );
    // metadataReporter.writeJsonReportMarket(report);
  }
}
// 0x783fDF6b9494e6e9DAcFF1f938904Fc47642271F - partial,  0x738eFcb730050f508B6778D49024A7Cd1481B36F - full

// devnet
// ambientSwapper 0xd411131B1Efc61006fc249D67C7BDD61fcd368F4
// flashLoaner 0x69b8Fcb74a5FbcCddE7bDb9b7Ec59a8Cb1AA5e2C
// swapController 0x42D4bf80e77114eBB049CBea29E1AB5A0727e9CA
// flashloanController 0x8De37B451C353AA6EEAc39dc28B6Ee82554BBa55
// loopStrategy 0x2B32bdf75e62f5f630b27af2F4c4CbBe6c2a69e2
// leverageStrategy 0xA504112baeCbA016DF1c22Da4Be6FA0be865F528

// devnet 2
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x9025Ea91308E0A55980e8cA6339026d3d662EB00
//   flashLoaner 0x8A38ae9D745D34c593FffaA8217168Ba18b13FC8
//   swapController 0x776Be3b64757e4143BCEd0be63060F38e80c873A
//   flashloanController 0xA2B05F84130Ee6a6F324BFFaA7FF9fA32305c21e
//   loopStrategy 0xA1874853E9a18631420F64e348DE00F0eF9bf5D5
//   leverageStrategy 0xB6cEEB7A3C17F0EE676DFA08566f8006a0b563cB

// 3
// ambientSwapper 0xce32f2f1eF99629f3721200468677b6004fBc411
//   flashLoaner 0x92949791601F61ed7B2Cd34eE9AAdC77Af7D7f9B
//   swapController 0x91eDb0E22869fB35B332617fDc3399ECFa14156e
//   flashloanController 0xa7E4F49Fd17c366E80f73332d44A711475Ba80C6
//   loopStrategy 0x17F6e6518E25400Ac2B8fd0F3517b0c1f97EE298
//   leverageStrategy 0xcC616B1E21181e857678765EA2119e64D5A72011

// mainnet 1
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x75FaCE9583A037bf0870Ef6D24f08e207D2CCdDc
//   flashLoaner 0x46b27CD4d8502F62DDa86F75a8087d226a90A776
//   swapController 0x0Cea2a4EAD71c1B2c1CB4D3D0114f34620222114
//   flashloanController 0x3748a6dE1B9EFC6D9584655d2aaDF498f53A918C
//   loopStrategy 0xdd43642EcbC09a5B0A89B032F19d5976fE31d024
//   leverageStrategy 0x620dc81757f9795213Ca88c6d6790A68ceB0a153

// mainnet 2
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x27846f8D7ab54f05be167628cd40B48e620e768B
//   flashLoaner 0xA3954b212F70C41c2f54fe6E5684BAa09FF775b3
//   swapController 0xC473008F1e9cac6Ef14690c7444f3cf391f6B526
//   flashloanController 0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A
//   loopStrategy 0x0ffbaF1Fb8De90DdA77feb3963feFE5204091Cb0
//   leverageStrategy 0x94F92CdA0f9017f4B8daab1a6b681C04a4871140

// mainnet 3
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x6A9Bcc9107C52C50E9b096daC7268BE9F0d028f8  old - 0xa8A18e3C1B5c51bcC64332f23FC4B1BB0ab64cCa
//   flashLoaner 0xA3954b212F70C41c2f54fe6E5684BAa09FF775b3
//   swapController 0x0f8d9480ca937441c166E39e2d9f90a7A6031194
//   flashloanController 0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A
//   loopStrategy 0x1EdF7b468731b2a15A48fcA02D6949fcb7f3D8f6
//   leverageStrategy 0x5E71B0de6c8B71997941fbF15E399ab8dcd125AE  old - 0x5C4DdF6b3d65E7cfF4A6b0B1Ee4DcF45b4A08246
