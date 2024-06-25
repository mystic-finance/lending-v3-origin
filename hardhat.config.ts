/** @type import('hardhat/config').HardhatUserConfig */

require('@nomicfoundation/hardhat-toolbox');
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-verify');
require('dotenv').config();
// require("@nomicfoundation/hardhat-foundry");

module.exports = {
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {enabled: true, runs: 200},
          evmVersion: 'shanghai',
        },
      },
      {
        version: '0.7.5',
        settings: {
          optimizer: {enabled: true, runs: 200},
        },
      },
    ],
  },
  networks: {
    hardhat: {},
    'plume-testnet': {
      url: 'https://testnet-rpc.plumenetwork.xyz/http',
      chainId: 161221135,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      'plume-testnet': 'test',
    },
    customChains: [
      {
        network: 'plume-testnet',
        chainId: 161221135,
        urls: {
          apiURL: 'https://testnet-explorer.plumenetwork.xyz/api?',
          browserURL: 'https://testnet-explorer.plumenetwork.xyz',
        },
      },
    ],
  },

  paths: {
    sources: './src',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  compilerOptions: {
    // paths: {
    //   'src/core/*': ['src/core/*'],
    //   'src/periphery/*': ['src/periphery/*'],
    // },
    target: 'es2020',
    module: 'commonjs',
    esModuleInterop: true,
    forceConsistentCasingInFileNames: true,
    strict: true,
    skipLibCheck: true,
    resolveJsonModule: true,
  },
};
