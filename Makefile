# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
test   :; forge test -vvv --no-match-contract DeploymentsGasLimits
test-contract :; forge test --match-contract ${filter} -vvv
test-watch   :; forge test --watch -vvv --no-match-contract DeploymentsGasLimits
coverage :; forge coverage --report lcov && \
	lcov --remove ./lcov.info -o ./lcov.info.p \
	'scripts/*' \
	'tests/*' \
	'src/deployments/*' \
	'src/periphery/contracts/v3-config-engine/*' \
	'src/periphery/contracts/treasury/*' \
	'src/periphery/contracts/dependencies/openzeppelin/ReentrancyGuard.sol' \
	'src/periphery/contracts/misc/UiIncentiveDataProviderV3.sol' \
	'src/periphery/contracts/misc/UiPoolDataProviderV3.sol' \
	'src/periphery/contracts/misc/WalletBalanceProvider.sol' \
	'src/periphery/contracts/mocks/*' \
	'src/core/contracts/mocks/*' \
	'src/core/contracts/dependencies/*' \
	'src/core/contracts/misc/AaveProtocolDataProvider.sol' \
	'src/core/contracts/protocol/libraries/configuration/*' \
	'src/core/contracts/protocol/libraries/logic/GenericLogic.sol' \
	'src/core/contracts/protocol/libraries/logic/ReserveLogic.sol' \
	&& genhtml ./lcov.info.p -o report --branch-coverage \
	&& coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# ## initial deploy
# deploy-script-test-arb-sepolia :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --verify --slow  -vvv --with-gas-price 200000000 --gas-estimate-multiplier 150 --delay 5
# deploy-script-plume-devnet3 :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api --legacy --gas-estimate-multiplier 5000 --delay 5
# update-script-plume-devnet3 :; forge script scripts/misc/UpdateAaveV3MarketBatchedBase.sol:UpdateAaveV3MarketBatchedBase --chain 98864 --rpc-url plume3 -vvvv --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api --legacy --gas-estimate-multiplier 500 --delay 5 
# deploy-script-plume-devnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
# deploy-script-test-polygon :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --verify --legacy --delay 5 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-script-strategy-plume-devnet :; forge script scripts/DeployStrategies.sol:DeployStrategies --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5 -vvv
deploy-script-strategy-plume-mainnet :; forge script scripts/DeployStrategies.sol:DeployStrategies --chain 98866 --rpc-url plume_mainnet --broadcast --verify --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --delay 5 --gas-estimate-multiplier 100 -vvvvv 

# pre-deposit
deploy-script-predeposit-vault :; forge script scripts/DeployPreDepositVaults.sol:DeployPreDepositVault --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5 -vvv
deploy-script-predeposit-vault-sepolia :; forge script scripts/DeployPreDepositVaults.sol:DeployPreDepositVault --chain 11155111 --rpc-url sepolia --broadcast --slow --verify --verifier etherscan --etherscan-api-key 53ADA6IG66V38YVY8GBXX1F8DJFVD38248 --legacy --delay 5 -vvv
deploy-script-predeposit-vault-polygon :; forge script scripts/DeployPreDepositVaults.sol:DeployPreDepositVault --chain 137 --rpc-url polygon --broadcast --slow --verify --verifier etherscan --etherscan-api-key XTQMYH2JDHAMKD4CQW8TV3QPR2RUAP8M6M --legacy --delay 5 -vvv
deploy-script-predeposit-vault-ethereum :; forge script scripts/DeployPreDepositVaults.sol:DeployPreDepositVault --chain 1 --rpc-url mainnet --broadcast --slow --verify --verifier etherscan --etherscan-api-key 53ADA6IG66V38YVY8GBXX1F8DJFVD38248 --delay 5 -vvv

## --resume to resume txn
# Gas reports
gas-report :; forge test --mp 'tests/gas/*.t.sol' --isolate


## initial deploy
deploy-script-test-arb-sepolia :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --verify --slow  -vvv --with-gas-price 200000000 --gas-estimate-multiplier 150 --delay 5
deploy-script-plume-devnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5 -vvvvvvvvvv
deploy-script-plume-devnet-resume :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --resume --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-test-polygon :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --verify --legacy --delay 5 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-script-plume-mainnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume-mainnet-gateway :; forge script scripts/DeployAaveWToken.sol:DeployGateway --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume3-gateway :; forge script scripts/DeployAaveWToken.sol:DeployGateway --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
update-pool-script-plume-mainnet :; forge script scripts/DeployAaveNewImpl.sol:DeployNewImpl --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5


## list tokens on pool
deploy-list-asset-arb-sepolia :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --slow --verify -vvv --with-gas-price 200000000  --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-plume :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --slow --sender 0x4C741E7f98B166286157940Bc7bb86EBaEC51D0a --delay 5
deploy-list-asset-plume2 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --delay 5
deploy-list-asset-plume3 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --delay 5 --gas-estimate-multiplier 5000 -vvv
deploy-list-asset-plume-verify :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --legacy --slow --verifier blockscout --verifier-url https://plume-testnet.explorer.caldera.xyz/api --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-polygon :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5 -vvv

## vault dpeloyment
# deploy-aave-bundler-plume :; forge script scripts/DeployAaveBundler.sol:Default --chain 161221135 --rpc-url plume --broadcast --force  -vvvv --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-aave-vault-plume-devnet :; forge script scripts/DeployAaveVault.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
deploy-aave-vault-plume-testnet :; forge script scripts/DeployAaveVault.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --legacy --gas-estimate-multiplier 5000 --delay 5
verify-aave-vault-factory-plume-testnet :; forge verify-contract 0x2765968702d8f4839f587Bdc8A3c02697d182d2c src/core/contracts/protocol/vault/VaultFactory.sol:MysticPoolVaultFactory --chain 98864 --rpc-url plume3 --verifier blockscout --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch
verify-aave-vault-plume-testnet :; forge verify-contract 0x5f1C7c723a2938b837B21Dc1158480098F382128 src/core/contracts/protocol/vault/MysticVault.sol:MysticVault --chain 98864 --rpc-url plume3 --verifier blockscout --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch


## verify contracts
plume3-verify-impl :; forge verify-contract 0xEd2D5f8F6bE71F740c89dEf37c6535f7A07B6F83 --chain 98864 --verifier blockscout src/core/instances/L2PoolInstance.sol:L2PoolInstance  --rpc-url plume3 --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch  --constructor-args 0x00000000000000000000000036Ded1E98d43a74679eF43589c59DBE34AdDc80c --libraries src/core/contracts/protocol/libraries/logic/BorrowLogic.sol:BorrowLogic:0xEb11a4a960AFBC9505Cece36aeCE85F42ca62ce8 --libraries src/core/contracts/protocol/libraries/logic/BridgeLogic.sol:BridgeLogic:0x11B96c434610faB7363882a65B518b0253EEE1C2  --libraries src/core/contracts/protocol/libraries/logic/EModeLogic.sol:EModeLogic:0xB9bc838F9BAD6cF18AcbBb8Df84b0c442bc55400 --libraries src/core/contracts/protocol/libraries/logic/FlashLoanLogic.sol:FlashLoanLogic:0x66c153D4F50CE4858b65Ce427372A8E2150f621b --libraries src/core/contracts/protocol/libraries/logic/LiquidationLogic.sol:LiquidationLogic:0xe355F60Bf5a74212F7D02acB0c6CE63B818905D0 --libraries src/core/contracts/protocol/libraries/logic/PoolLogic.sol:PoolLogic:0x61A4eBbAcDEa5a672c81308570ff9E862d337C27 --libraries src/core/contracts/protocol/libraries/logic/SupplyLogic.sol:SupplyLogic:0x56A82eB552dAC3828B8d576eB62da4999Df970d3 
# --show-standard-json-input > etherscan.json
plume3-verify-poolproxy :; forge verify-contract 0xd7ecf5312aa4FE7ddcAAFba779494fBC5f5f459A src/core/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol:InitializableImmutableAdminUpgradeabilityProxy --rpc-url plume3 --verifier blockscout --verifier-url 'https://test-explorer.plumenetwork.xyz/api?'
plume3-verify-uipool :; forge verify-contract 0x9652674BFc6Be8C2508822DC979b3244AC28f04b  --chain 98864 --verifier blockscout src/periphery/contracts/misc/UiPoolDataProviderV3.sol:UiPoolDataProviderV3  --rpc-url plume3 --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch
plume-verify-strategy :; forge verify-contract 0x5E71B0de6c8B71997941fbF15E399ab8dcd125AE  --chain 98865 --verifier blockscout src/core/contracts/protocol/strategies/LeverageStrategy.sol:LeveragedBorrowingVault  --rpc-url plume_mainnet --verifier-url https://explorer.plumenetwork.xyz/api? --watch  --constructor-args 0x000000000000000000000000d5b3495c5e059a23bea726166e3c46b0cb3b42ab0000000000000000000000000f8d9480ca937441c166e39e2d9f90a7a60311940000000000000000000000005fa6836e652d7d43089eac7df3a8360b5ccdcf9a
plume-verify-strategy-2 :; forge verify-contract 0xB70F69F4D93EFb3fd95592feDA17aE5b61E2eb56  --chain 98866 --verifier blockscout src/core/contracts/protocol/strategies/LeverageStrategy02.sol:LeveragedBorrowingVault02  --rpc-url plume_mainnet --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --watch 
plume-verify-points :; forge verify-contract 0xC79F50AEaeaF85B320350Dbe83773250c1329c69  --chain 98866 --verifier blockscout src/core/contracts/protocol/preDeposits/Points.sol:Points  --rpc-url plume_mainnet --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --watch  

verify-oracle :; forge verify-contract 0x59AB56F7285e723CD417aFf63EEea800fD037995 --chain 137 --verifier etherscan --etherscan-api-key XTQMYH2JDHAMKD4CQW8TV3QPR2RUAP8M6M --rpc-url polygon src/EmergencyEACProxy.sol:EEACAggregatorProxy --watch --constructor-args 0x00000000000000000000000036da71ccad7a67053f0a4d9d5f55b725c9a25a3e000000000000000000000000000000000000000000000000000000000000000021c4f9a7edaefc4d28ba07193e0a7f13858fc363002378434608f3296ae1c676

# plume3-verify-standard :; forge verify-contract 0xEd2D5f8F6bE71F740c89dEf37c6535f7A07B6F83  --chain 98864 --verifier blockscout src/core/instances/L2PoolInstance.sol:L2PoolInstance  --rpc-url plume3 --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch --constructor-args 0x00000000000000000000000036Ded1E98d43a74679eF43589c59DBE34AdDc80c --show-standard-json-input > etherscan.json


plume3-check-logic :; forge script scripts/CheckPoolLogic.sol:CheckPoolLogic --chain 98864 --rpc-url https://test-rpc.plumenetwork.xyz -vvvv
simulate-txn :; cast call 0x2e4e91890fa1d183c38C55096BBCd220FaF55E32 $data --rpc-url $RPC --trace --debug
simulate-test-uipool :; cast call  0xa576002f209C9F81DaC7A25A88Ab103335569851 0xec489c210000000000000000000000006a5f6b4f1c7b8afa16a941d52c4d706210e9ed2f --rpc-url https://phoenix-rpc.plumenetwork.xyz --trace
simulate-liquidation :; cast call  0x1a90F585d95a2AA0DD7989686B4b45139A9f0989 0x0ddc695200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc80000000000000000000000001da3081c2d52795459f99ae7de40c1e339b3bbf10000000000000000000000000000000000000000000000000000003a35294400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bb800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000640000000000000000000000004e9a5601e94beb8e8a771d233e45577fe6a430dd0000000000000000000000000000000000000000000000000000000000000000 --rpc-url https://arbitrum-one-rpc.publicnode.com --from 0x4e9a5601e94beb8e8a771d233e45577fe6a430dd --trace

## test  
test-predeposit :; forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/vBjfr1U4i_Ggbhu60Q7TV-jlx3aKXHWL --mc StoneBeraVaultTest3 --mt test_deposit_basic_b  -vvv
test-leverage :; forge test --mc LeveragedBorrowingVaultTest  -vvv
test-loop :; forge test --mc AdvancedLoopStrategyTest  -vvv
test-leverage-fork :; forge test --fork-url https://phoenix-rpc.plumenetwork.xyz --mc LeveragedBorrowingVaultForkTest  -vvv
test-leverage-devnet-fork :; forge test --fork-url https://rpc-plume-testnet-m8kfz7osif.t.conduit.xyz --mc LeveragedBorrowingVaultDevnetForkTest  -vvv
test-leverage-devnet-fork-02 :; forge test --fork-url https://rpc-plume-testnet-m8kfz7osif.t.conduit.xyz --mc LeveragedBorrowing02VaultDevnetForkTest --fork-retries 3  --ffi --no-rpc-rate-limit -vvv
test-open-leverage-fork :; forge test --fork-url https://phoenix-rpc.plumenetwork.xyz --mc LeveragedBorrowingVaultForkTest  -vvv
test-open-leverage-fork-02 :; forge test --fork-url https://phoenix-rpc.plumenetwork.xyz --mc LeveragedBorrowingVault02ForkTest --no-rpc-rate-limit -vvv
test-loop-fork :; forge test --fork-url https://test-rpc.plumenetwork.xyz --mc LeveragedBorrowingVaultTest  -vvv
test-liquidator-fork-spec :; forge test --mc FlashMintLiquidatorTest --mt test_liquidateWithFlashLoan  -vvv
test-liquidator-fork-fls :; forge test --mc FlashMintLiquidatorTest --mt test_liquidateWithFlashLoan  -vvvv
test-liquidator-fork :; forge test --mc FlashMintLiquidatorTest  -vvv
