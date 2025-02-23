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
import {MaverickSwap} from 'src/core/contracts/protocol/strategies/Swap/MaverickSwapper.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployStrategies is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address lendingPool = vm.envAddress('LENDING_POOL');
    address poolProvider = vm.envAddress('POOL_PROVIDER');
    address quoter = vm.envAddress('MAVERICK_QUOTER');
    address factory = vm.envAddress('MAVERICK_FACTORY');

    vm.startBroadcast(deployerPrivateKey);

    // AaveV3BatchOrchestration.updateProviderRegistry(
    //   report.poolAddressesProviderRegistry,
    //   0x1E4aC9797E50bdb9706df99a45dB6afaff212239,
    //   config.providerId
    // );
    // MaverickSwap ambientSwapper = new MaverickSwap(factory, quoter);
    AaveV3Flashloaner flashLoaner = new AaveV3Flashloaner(poolProvider);

    // SwapController swapController = new SwapController(address(ambientSwapper));
    FlashLoanController flashloanController = new FlashLoanController(address(flashLoaner));

    // SwapController swapController = SwapController(0x0f8d9480ca937441c166E39e2d9f90a7A6031194);
    // swapController.updateSwapper(address(ambientSwapper));

    // AdvancedLoopStrategy loopStrategy = new AdvancedLoopStrategy(
    //   msg.sender,
    //   lendingPool,
    //   address(swapController),
    //   500
    // );
    // LeveragedBorrowingVault leverageStrategy = new LeveragedBorrowingVault(
    //   lendingPool,
    //   address(swapController),
    //   address(flashloanController)
    // );

    AdvancedLoopStrategy loopStrategy = AdvancedLoopStrategy(
      0x1EdF7b468731b2a15A48fcA02D6949fcb7f3D8f6
    );
    LeveragedBorrowingVault leverageStrategy = LeveragedBorrowingVault(
      0x249328B0F91A21eEcBf89862B9b181c522CEa5d5
    );
    leverageStrategy.updateFlashLoanController(address(flashloanController));

    // console.log('ambientSwapper', address(ambientSwapper));
    console.log('flashLoaner', address(flashLoaner));
    // console.log('swapController', address(swapController));
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
    // leverageStrategy.addAllowedBorrowToken(0xe644F07B1316f28a7F134998e021eA9f7135F351);
    // leverageStrategy.addAllowedBorrowToken(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74);
    // leverageStrategy.addAllowedBorrowToken(0x2413b8C79Ce60045882559f63d308aE3DFE0903d);
    // leverageStrategy.addAllowedBorrowToken(0x401eCb1D350407f13ba348573E5630B83638E30D);
    // leverageStrategy.addAllowedBorrowToken(0x1738E5247c85f96c9D35FE55800557C5479b7063);

    // leverageStrategy.addAllowedCollateralToken(0xe644F07B1316f28a7F134998e021eA9f7135F351);
    // leverageStrategy.addAllowedCollateralToken(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74);
    // leverageStrategy.addAllowedCollateralToken(0x2413b8C79Ce60045882559f63d308aE3DFE0903d);
    // leverageStrategy.addAllowedCollateralToken(0x401eCb1D350407f13ba348573E5630B83638E30D);
    // leverageStrategy.addAllowedCollateralToken(0x1738E5247c85f96c9D35FE55800557C5479b7063);
    vm.stopBroadcast();
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

// devnet 4
// ambientSwapper 0xb25ca6d7e24fc02A238d9b3e5765B27C11f265CC 0xE9e3A2027f049720911227BF39413EEB7332Dcf8-old
//   flashLoaner 0x63FbEfEff35f399A5a571065bdE9Ef82aD430FB1 0x87776ADE28Cf941FA768c146Aa8F6AE8DBEa56fE-old
//   swapController 0x441346b778C7e448817C7184ed7f6F3F486114E9
//   flashloanController 0x82AF37745de0F329B3A21C3EBCDBCD2Cf5F5a518  0x1b3064AA01e9351B9CfF1742043896e9663cAa09-old
//   loopStrategy 0x1969A5aE50c5e3e73999F3bfE86221a3dd6BA254
//   leverageStrategy 0xBF864AD33002b46996CbF4168312a2aB679217F4

// devnet 5
// ambientSwapper 0x3B98281c40AaC5D9A951b7A751Da1a3b42D35D8b
//   flashLoaner 0x5Ce4bdC204AC1b7fc2A4a8A0B1a410d5Ab3DA2F9
//   swapController 0x0499F76FC708C81a0EF8b3349e1A87d8dBa77b8f
//   flashloanController 0x5d6532D7b179486C103258a8358bdBf9078CAA54
//   loopStrategy 0xEDc7a3e126dF21EEbFB0f9806d5b4dcD6db82f21
//   leverageStrategy 0x2834EFEb7987223Bf07e996052d8077f6Fe7DF32

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
//   flashLoaner 0xB5f78941c89eA03Ea9c26Ff642B57D8aedB6AFf2  0xA3954b212F70C41c2f54fe6E5684BAa09FF775b3 - old
//   swapController 0xD914F98AF8197cc461e9F1237d8D76e3b332D6c8  old - 0x0f8d9480ca937441c166E39e2d9f90a7A6031194
//   flashloanController 0x0f9eA60Bb83b8B8d38F59580a40e92C6301b4A6F  0x5fA6836e652d7d43089EAc7df3a8360b5ccdCf9A-old
//   loopStrategy 0x1EdF7b468731b2a15A48fcA02D6949fcb7f3D8f6
//   leverageStrategy 0x249328B0F91A21eEcBf89862B9b181c522CEa5d5 old - 0x5E71B0de6c8B71997941fbF15E399ab8dcd125AE  older - 0x5C4DdF6b3d65E7cfF4A6b0B1Ee4DcF45b4A08246
