/** @type import('hardhat/config').HardhatUserConfig */

require('@nomicfoundation/hardhat-toolbox');
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
          evmVersion: 'paris',
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
