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
import {LeveragedBorrowingVault02} from 'src/core/contracts/protocol/strategies/LeverageStrategy02.sol';
import {MaverickSwap} from 'src/core/contracts/protocol/strategies/Swap/MaverickSwapper.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployStrategies is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    console.log('sender', msg.sender);

    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address lendingPool = vm.envAddress('LENDING_POOL');
    // address poolProvider = vm.envAddress('POOL_PROVIDER');
    // address quoter = vm.envAddress('MAVERICK_QUOTER');
    // address factory = vm.envAddress('MAVERICK_FACTORY');

    vm.startBroadcast(deployerPrivateKey);

    // AaveV3BatchOrchestration.updateProviderRegistry(
    //   report.poolAddressesProviderRegistry,
    //   0x1E4aC9797E50bdb9706df99a45dB6afaff212239,
    //   config.providerId
    // );
    // MaverickSwap ambientSwapper = new MaverickSwap(factory, quoter);
    // AmbientSwap swap = new AmbientSwap(0xAaAaAAAA81a99d2a05eE428eC7a1d8A3C2237D85, lendingPool);
    // MaverickSwap swap = new MaverickSwap(
    //   0x056A588AfdC0cdaa4Cab50d8a4D2940C5D04172E,
    //   0xf245948e9cf892C351361d298cc7c5b217C36D82
    // ); //factory, quoter

    // AaveV3Flashloaner flashLoaner = new AaveV3Flashloaner(poolProvider);

    // SwapController swapController = new SwapController(address(ambientSwapper));
    // FlashLoanController flashloanController = new FlashLoanController(address(flashLoaner));

    // SwapController swapController = SwapController(0x9e05D90f40ABd231C7B482449de9e1872F94A3c4);
    // swapController.updateSwapper(address(swap));

    // AdvancedLoopStrategy loopStrategy = new AdvancedLoopStrategy(
    //   msg.sender,
    //   lendingPool,
    //   address(swapController),
    //   500
    // );
    // LeveragedBorrowingVault leverageStrategy = new LeveragedBorrowingVault(
    //   lendingPool,
    //   0x9e05D90f40ABd231C7B482449de9e1872F94A3c4,
    //   0xDc559b3af6aB03B82753f0808cc33eB1eeb51734
    // );

    LeveragedBorrowingVault02 leverageStrategy = new LeveragedBorrowingVault02(
      lendingPool,
      0x9e05D90f40ABd231C7B482449de9e1872F94A3c4,
      0xDc559b3af6aB03B82753f0808cc33eB1eeb51734
    );

    // AdvancedLoopStrategy loopStrategy = AdvancedLoopStrategy(
    //   0x1EdF7b468731b2a15A48fcA02D6949fcb7f3D8f6
    // );
    // LeveragedBorrowingVault leverageStrategy = LeveragedBorrowingVault(
    //   0xC5b1009a2C098378e7a08900e4b6e46a1bF32Da2
    // );
    // leverageStrategy.updateFlashLoanController(address(flashloanController));

    // console.log('swapper', address(swap));
    // console.log('flashLoaner', address(flashLoaner));
    // console.log('swapController', address(swapController));
    // console.log('flashloanController', address(flashloanController));
    // console.log('loopStrategy', address(loopStrategy));
    console.log('leverageStrategy', address(leverageStrategy));
    // console.log('leverageStrategy02', address(leverageStrategy02));
    address[] memory borrowTokens = new address[](5);
    address[] memory collateralTokens = new address[](7);

    // Populate borrowTokens array
    borrowTokens[0] = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1; // plume
    borrowTokens[1] = 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F; // pusd
    borrowTokens[2] = 0xca59cA09E5602fAe8B629DeE83FfA819741f14be; // weth
    borrowTokens[3] = 0x78adD880A697070c1e765Ac44D65323a0DcCE913; // usdc
    borrowTokens[4] = 0xda6087E69C51E7D31b6DBAD276a3c44703DFdCAd; // usdt

    // Populate collateralTokens array
    collateralTokens[0] = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1; // plume
    collateralTokens[1] = 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F; // pusd
    collateralTokens[2] = 0x593cCcA4c4bf58b7526a4C164cEEf4003C6388db; // nrwa
    collateralTokens[3] = 0xE72Fe64840F4EF80E3Ec73a1c749491b5c938CB9; // nelixir
    collateralTokens[4] = 0x9fbC367B9Bb966a2A537989817A088AFCaFFDC4c; // ntbill
    collateralTokens[5] = 0xca59cA09E5602fAe8B629DeE83FfA819741f14be; // weth
    collateralTokens[6] = 0x39d1F90eF89C52dDA276194E9a832b484ee45574; // peth

    // Call batch functions
    leverageStrategy.batchAddAllowedBorrowTokens(borrowTokens);
    leverageStrategy.batchAddAllowedCollateralTokens(collateralTokens);

    // mainnet
    // leverageStrategy.addAllowedBorrowToken(0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1); //plume
    // leverageStrategy.addAllowedBorrowToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F); //pusd
    // // leverageStrategy.addAllowedBorrowToken(0x593cCcA4c4bf58b7526a4C164cEEf4003C6388db); // nrwa
    // // leverageStrategy.addAllowedBorrowToken(0xE72Fe64840F4EF80E3Ec73a1c749491b5c938CB9); //nelixir
    // // leverageStrategy.addAllowedBorrowToken(0x9fbC367B9Bb966a2A537989817A088AFCaFFDC4c); //ntbill
    // leverageStrategy.addAllowedBorrowToken(0xca59cA09E5602fAe8B629DeE83FfA819741f14be); // weth
    // leverageStrategy.addAllowedBorrowToken(0x78adD880A697070c1e765Ac44D65323a0DcCE913); //usdc
    // leverageStrategy.addAllowedBorrowToken(0xda6087E69C51E7D31b6DBAD276a3c44703DFdCAd); //usdt
    // // leverageStrategy.addAllowedBorrowToken(0x39d1F90eF89C52dDA276194E9a832b484ee45574); // peth

    // leverageStrategy.addAllowedCollateralToken(0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1);
    // leverageStrategy.addAllowedCollateralToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    // leverageStrategy.addAllowedCollateralToken(0x593cCcA4c4bf58b7526a4C164cEEf4003C6388db);
    // leverageStrategy.addAllowedCollateralToken(0xE72Fe64840F4EF80E3Ec73a1c749491b5c938CB9);
    // leverageStrategy.addAllowedCollateralToken(0x9fbC367B9Bb966a2A537989817A088AFCaFFDC4c);
    // leverageStrategy.addAllowedCollateralToken(0xca59cA09E5602fAe8B629DeE83FfA819741f14be);
    // // leverageStrategy.addAllowedCollateralToken(0x78adD880A697070c1e765Ac44D65323a0DcCE913);
    // // leverageStrategy.addAllowedCollateralToken(0xda6087E69C51E7D31b6DBAD276a3c44703DFdCAd);
    // leverageStrategy.addAllowedCollateralToken(0x39d1F90eF89C52dDA276194E9a832b484ee45574);

    // 02
    // leverageStrategy.addAllowedBorrowToken(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
    // leverageStrategy.addAllowedCollateralToken(0x9fbC367B9Bb966a2A537989817A088AFCaFFDC4c);

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

// mainnet 4
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x7E620391AC654Dad79C1c15d6Af2bB83B813fF59
//   flashLoaner 0x9E794C6Db6DCdF82aE43716Ef697B4B4f8a139c8
//   swapController 0x7942cEC0A6a6C02B78845E836C9BE96aa39F57Bf
//   flashloanController 0xB8e5A61D8518761F271409A236a1F1706CCEe69D
//   loopStrategy 0x9Bd7e6b833BF7c2B1Db2703EFA68B1e38d594848
//   leverageStrategy 0x8088DD0042641195E0F35f250Eb0A2D3892456a0

// mainnet 1-1
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x8263AF89b721799bB59fF58f38147beeE2D15DdB
//   flashLoaner 0xe0dFB1C58eD32429ad74BB73187aeC2F97e6E3A4
//   swapController 0x9e05D90f40ABd231C7B482449de9e1872F94A3c4
//   flashloanController 0xDc559b3af6aB03B82753f0808cc33eB1eeb51734
//   loopStrategy 0x0900C8DcDDdBFE1f0357fF147459a0CAc83997cc
//   leverageStrategy 0xC5b1009a2C098378e7a08900e4b6e46a1bF32Da2

// mainnet 1-2
// == Logs ==
//   Aave V3 Batch Listing
//   sender 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
//   ambientSwapper 0x8263AF89b721799bB59fF58f38147beeE2D15DdB
//   flashLoaner 0xe0dFB1C58eD32429ad74BB73187aeC2F97e6E3A4
//   swapController 0x9e05D90f40ABd231C7B482449de9e1872F94A3c4
//   flashloanController 0xDc559b3af6aB03B82753f0808cc33eB1eeb51734
//   loopStrategy 0x0900C8DcDDdBFE1f0357fF147459a0CAc83997cc
//   leverageStrategy 0xBAb83b11e15c111A580Ce593c783Fe41B4CCd7f0
//   leverageStrategy02 0x5443e4937ACA73d16f051075bB6aA28ABBcc2fE6

// == Logs ==
//   swapper 0x544132816A358D457Db256e6C0334Ebdaa687970
//   leverageStrategy 0x96dD2B982b02EA452dFEE8C97Fe4C389E8Ff972E
//   leverageStrategy02 0x269871d6a01d61A67340A3c3Ed5D3c50d69577e0
