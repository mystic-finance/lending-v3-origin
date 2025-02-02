// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import 'src/deployments/interfaces/IMarketReportTypes.sol';
import {DeployUtils} from 'src/deployments/contracts/utilities/DeployUtils.sol';
import {MainOracle} from 'src/core/contracts/protocol/strategies/PreDeposits/oracle/MainOracle.sol';
import {OracleConfigurator} from 'src/core/contracts/protocol/strategies/PreDeposits/oracle/OracleConfigurator.sol';
import {Token} from 'src/core/contracts/protocol/strategies/PreDeposits/Token.sol';
import {StoneBeraVault} from 'src/core/contracts/protocol/strategies/PreDeposits/BeraPreDepositVault.sol';

import {DefaultMarketInput} from 'src/deployments/inputs/DefaultMarketInput.sol';

contract DeployPreDepositVault is DeployUtils, DefaultMarketInput, Script {
  using stdJson for string;

  function run() external {
    console.log('Aave V3 Batch Listing');
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address token = vm.envAddress('NEW_TOKEN');
    // address poolProvider = vm.envAddress('POOL_PROVIDER');
    // address ambientSwap = vm.envAddress('AMBIENT_SWAP');

    vm.startBroadcast(deployerPrivateKey);
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer address:", deployer);
    console.log('sender', msg.sender);

    MainOracle mainOracle = new MainOracle(token, "usdc oracle", 1e18);
    OracleConfigurator configurator = new OracleConfigurator();

    configurator.grantRole(configurator.ORACLE_MANAGER_ROLE(), deployer);
    configurator.updateOracle(token, address(mainOracle));

    Token lpToken = new Token("Mystic Pre-Deposit LP","MPLP");
    StoneBeraVault vault = new StoneBeraVault(address(lpToken), token, address(configurator), 1e7);
    console.log('has role', lpToken.hasRole(lpToken.DEFAULT_ADMIN_ROLE(), deployer));

    lpToken.grantRole(lpToken.MINTER_ROLE(), address(vault));
    

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