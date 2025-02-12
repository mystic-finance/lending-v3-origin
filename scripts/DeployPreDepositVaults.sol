// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {DeployUtils} from 'src/deployments/contracts/utilities/DeployUtils.sol';
// import {MainOracle} from 'src/core/contracts/protocol/PreDeposits/oracle/MainOracle.sol';
import {MainOracleV2} from 'src/core/contracts/protocol/PreDeposits/oracle/MainOracleV2.sol';

import {OracleConfigurator} from 'src/core/contracts/protocol/PreDeposits/oracle/OracleConfigurator.sol';
import {Token} from 'src/core/contracts/protocol/PreDeposits/Token.sol';
import {StoneBeraVault} from 'src/core/contracts/protocol/PreDeposits/BeraPreDepositVault.sol';
import {DepositWrapper} from "src/core/contracts/protocol/preDeposits/ETHDepositWrapper.sol";
import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployPreDepositVault is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address usdc = vm.envAddress('USDC');
    address weth = vm.envAddress('WETH');
    address usdcproxy = vm.envAddress('USDC_AGGREGATOR');
    address wethProxy = vm.envAddress('WETH_AGGREGATOR');
    // address ambientSwap = vm.envAddress('AMBIENT_SWAP');

    vm.startBroadcast(deployerPrivateKey);
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer address:", deployer);
    console.log('sender', msg.sender);

    MainOracleV2 mainOracle = new MainOracleV2(usdc, "usdc oracle", usdcproxy);
    MainOracleV2 mainOracle2 = new MainOracleV2(weth, "weth oracle", wethProxy);
    OracleConfigurator configurator = new OracleConfigurator();

    configurator.grantRole(configurator.ORACLE_MANAGER_ROLE(), deployer);
    configurator.updateOracle(usdc, address(mainOracle));
    configurator.updateOracle(weth, address(mainOracle2));
    // deploy configurator
    // deploy two oracles
    // deploy lp token
    // dpeloy vault
    // map assets to oracles
    // give toles to deployer
    // add underlying asset to vault

    Token lpToken = new Token("Mystic PreDeposit LP Token","MPLT");
    StoneBeraVault vault = new StoneBeraVault(address(lpToken), usdc, address(configurator), 10000000e18);
    console.log('has role', lpToken.hasRole(lpToken.DEFAULT_ADMIN_ROLE(), deployer));

    lpToken.grantRole(lpToken.MINTER_ROLE(), address(vault));
    lpToken.grantRole(lpToken.BURNER_ROLE(), address(vault));

    // StoneBeraVault vault = StoneBeraVault(0x678c562BeeDa3710066E8F3874352587b98BBb6F);
    // OracleConfigurator configurator = OracleConfigurator(0x1F263995486a9aCfD648D6Cff5206f090c54470f);
    // MainOracle mainOracleEth = new MainOracle(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74, "eth oracle", 3000e18);

    configurator.updateOracle(usdc, address(mainOracle));
    configurator.updateOracle(weth, address(mainOracle2));
    // configurator.updateOracle(0x401eCb1D350407f13ba348573E5630B83638E30D, address(mainOracle));
    // configurator.updateOracle(0xaA6210015fbf0855F0D9fDA3C415c1B12776Ae74, address(mainOracle));
    vault.grantRole(vault.VAULT_OPERATOR_ROLE(), deployer);
    vault.grantRole(vault.ASSETS_MANAGEMENT_ROLE(), deployer);
    // vault.addUnderlyingAsset(0x2413b8C79Ce60045882559f63d308aE3DFE0903d); //usdt
    // vault.addUnderlyingAsset(0xe644F07B1316f28a7F134998e021eA9f7135F351); //pusd
    vault.addUnderlyingAsset(usdc); //usdc
    vault.addUnderlyingAsset(weth); //weth

    // vault.setCap(500000e18);
    // Token(0x2413b8C79Ce60045882559f63d308aE3DFE0903d).approve(address(vault), 1000000000);
    // vault.deposit(0x2413b8C79Ce60045882559f63d308aE3DFE0903d, 1000000, deployer);
    // DepositWrapper wrapper = new DepositWrapper(weth, 0xdC4C0661EC6BF350bB2AB63649161F8dBC4DfdC0);
    

    console.log('oracle', address(mainOracle));
    console.log('oracle configurator', address(configurator));
    console.log('lp token', address(lpToken));
    console.log('bera vault', address(vault));
    
    vm.stopBroadcast();

  }
}


// devnet
// oracle 0xE55ab85986C832CbC27C9f26054153023c199Cf4
//   oracle configurator 0x1F263995486a9aCfD648D6Cff5206f090c54470f
//   lp token 0x4F4457ae8858CeaBdeE17e7e046b062bdA29D0d6
//   bera vault 0x2D39f0D5d4b19D5d8f2B3d6757CB4BB5147b7447


// devnet 2
// oracle 0x4BE016EF0A511466940A4F906Df1dE0cd5b4D7Be
//   oracle configurator 0x467f9cFD695f756D26074CeAb76E8746A6262e43
//   lp token 0x679Ef28c7d66361cF87a384b171FaB676CD0b0B7
//   bera vault 0x678c562BeeDa3710066E8F3874352587b98BBb6F


// polygon
// has role true
  // oracle 0x5817FBBF26F7Da75E68363998987099C325577E0
  // oracle configurator 0x84571629B42ABc0464b0737860A061bF3832E6AF
  // lp token 0x7453A195331861DAeE128F04D8daa090f682b4E3
  // bera vault 0xdC4C0661EC6BF350bB2AB63649161F8dBC4DfdC0


// mainnet
// has role true
  // oracle 0xAfE6AC7C392B783C2CB14256A5b05DBF77761dC6 - usdc 0xfa19C25FbCA358be42692FcbB905998FE807dCdb - weth
  // oracle configurator 0x425DBc2dB879A9D88f259D15cAc45786ffE48c9C
  // lp token 0x04e2f381fEE12b0930bFDE5be98a735C9b448BBB
  // bera vault 0x29985c0adDa5fF2d5f716E428E43A460987D90A5