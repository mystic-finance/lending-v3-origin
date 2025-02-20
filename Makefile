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

## initial deploy
deploy-script-test-arb-sepolia :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --verify --slow  -vvv --with-gas-price 200000000 --gas-estimate-multiplier 150 --delay 5
deploy-script-plume-devnet3 :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5 -vvvvv
deploy-script-plume-devnet3-resume :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --resume --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume-devnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
deploy-script-test-polygon :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --verify --legacy --delay 5 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-script-plume-mainnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume-mainnet-gateway :; forge script scripts/DeployAaveWToken.sol:DeployGateway --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume3-gateway :; forge script scripts/DeployAaveWToken.sol:DeployGateway --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5
update-pool-script-plume-mainnet :; forge script scripts/DeployAaveNewImpl.sol:DeployNewImpl --chain 98865 --rpc-url plume_mainnet --broadcast --slow --verifier blockscout --verifier-url https://phoenix-explorer.plumenetwork.xyz/api? --legacy --gas-estimate-multiplier 5000 --delay 5


## list tokens on pool
deploy-list-asset-arb-sepolia :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --slow --verify -vvv --with-gas-price 200000000  --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-plume :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --slow --sender 0x4C741E7f98B166286157940Bc7bb86EBaEC51D0a --delay 5
deploy-list-asset-plume2 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --delay 5
deploy-list-asset-plume3 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --delay 5 --gas-estimate-multiplier 5000
deploy-list-asset-plume-mainnet :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 98865 --rpc-url plume_mainnet --broadcast --slow --delay 5 --gas-estimate-multiplier 5000

deploy-list-asset-plume-verify :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --legacy --slow --verifier blockscout --verifier-url https://plume-testnet.explorer.caldera.xyz/api --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-polygon :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5 -vvv

## vault dpeloyment
# deploy-aave-bundler-plume :; forge script scripts/DeployAaveBundler.sol:Default --chain 161221135 --rpc-url plume --broadcast --force  -vvvv --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-aave-vault-plume-devnet :; forge script scripts/DeployAaveVault.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
deploy-aave-vault-plume-testnet :; forge script scripts/DeployAaveVault.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --legacy --gas-estimate-multiplier 5000 --delay 5
verify-aave-vault-factory-plume-testnet :; forge verify-contract 0x2765968702d8f4839f587Bdc8A3c02697d182d2c src/core/contracts/protocol/vault/VaultFactory.sol:MysticPoolVaultFactory --chain 98864 --rpc-url plume3 --verifier blockscout --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch
verify-aave-vault-plume-testnet :; forge verify-contract 0x5f1C7c723a2938b837B21Dc1158480098F382128 src/core/contracts/protocol/vault/MysticVault.sol:MysticVault --chain 98864 --rpc-url plume3 --verifier blockscout --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch


## verify contracts
plume-verify-impl :; forge verify-contract 0x41a68A3851Bf8dDd6aF88B93FD21F453B6741e86 --chain 98865 --verifier blockscout src/core/instances/L2PoolInstance.sol:L2PoolInstance  --rpc-url plume_mainnet --verifier-url 'https://phoenix-explorer.plumenetwork.xyz/api?' --watch  --constructor-args 0x000000000000000000000000B3E7087077452305436F81391d4948025786e0c8 --libraries src/core/contracts/protocol/libraries/logic/BorrowLogic.sol:BorrowLogic:0x6e7DB49F12db72DCa59cB1f252709d720254C8f9 --libraries src/core/contracts/protocol/libraries/logic/BridgeLogic.sol:BridgeLogic:0x5c4458DD5F57BeCC2FD81E9b9c27b99203401413  --libraries src/core/contracts/protocol/libraries/logic/EModeLogic.sol:EModeLogic:0xB9bc838F9BAD6cF18AcbBb8Df84b0c442bc55400 --libraries src/core/contracts/protocol/libraries/logic/FlashLoanLogic.sol:FlashLoanLogic:0xdb5E1fd41960734392A29c98eee9b63e2d175027 --libraries src/core/contracts/protocol/libraries/logic/LiquidationLogic.sol:LiquidationLogic:0xDFD17459fa92FfDBc1A66C897Ed919e3DEa70559 --libraries src/core/contracts/protocol/libraries/logic/PoolLogic.sol:PoolLogic:0x61A4eBbAcDEa5a672c81308570ff9E862d337C27 --libraries src/core/contracts/protocol/libraries/logic/SupplyLogic.sol:SupplyLogic:0x0589b0a262DEC0EE18020486717BC286668b2493 
# --show-standard-json-input > etherscan.json
plume-verify-poolproxy :; forge verify-contract 0xd5b3495C5e059a23Bea726166E3C46b0Cb3b42Ab src/core/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol:InitializableImmutableAdminUpgradeabilityProxy --rpc-url plume_mainnet --verifier blockscout --verifier-url 'https://phoenix-explorer.plumenetwork.xyz/api?'
plume-verify-pool-provider :; forge verify-contract 0xB3E7087077452305436F81391d4948025786e0c8 src/core/contracts/protocol/configuration/PoolAddressesProvider.sol:PoolAddressesProvider --rpc-url plume_mainnet --verifier blockscout --verifier-url 'https://phoenix-explorer.plumenetwork.xyz/api?' --constructor-args 0x000000000000000000000000000000000000000000000000000000000000004000000000000000000000000037081c7c25284cee72947af90a13b7402f2eb6fb000000000000000000000000000000000000000000000000000000000000002341617665205633204d797374696320506c756d65204d61696e6e6574204d61726b65740000000000000000000000000000000000000000000000000000000000
plume-verify-token-gateway :; forge verify-contract 0xA58d82221825B88e90F2Dd35008dA1546E84e7D5 src/periphery/contracts/misc/WrappedTokenGatewayV3.sol:WrappedTokenGatewayV3 --watch --rpc-url plume_mainnet --verifier blockscout --verifier-url 'https://phoenix-explorer.plumenetwork.xyz/api?' --constructor-args 0x00000000000000000000000011476323d8dfcbafac942588e2f38823d2dd308e00000000000000000000000037081c7c25284cee72947af90a13b7402f2eb6fb000000000000000000000000d5b3495c5e059a23bea726166e3c46b0cb3b42ab
plume-verify-uipool :; forge verify-contract 0x9652674BFc6Be8C2508822DC979b3244AC28f04b  --chain 98864 --verifier blockscout src/periphery/contracts/misc/UiPoolDataProviderV3.sol:UiPoolDataProviderV3  --rpc-url plume3 --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch

verify-oracle :; forge verify-contract 0x59AB56F7285e723CD417aFf63EEea800fD037995 --chain 137 --verifier etherscan --etherscan-api-key XTQMYH2JDHAMKD4CQW8TV3QPR2RUAP8M6M --rpc-url polygon src/EmergencyEACProxy.sol:EEACAggregatorProxy --watch --constructor-args 0x00000000000000000000000036da71ccad7a67053f0a4d9d5f55b725c9a25a3e000000000000000000000000000000000000000000000000000000000000000021c4f9a7edaefc4d28ba07193e0a7f13858fc363002378434608f3296ae1c676

# plume3-verify-standard :; forge verify-contract 0xEd2D5f8F6bE71F740c89dEf37c6535f7A07B6F83  --chain 98864 --verifier blockscout src/core/instances/L2PoolInstance.sol:L2PoolInstance  --rpc-url plume3 --verifier-url 'https://test-explorer.plumenetwork.xyz/api?' --watch --constructor-args 0x00000000000000000000000036Ded1E98d43a74679eF43589c59DBE34AdDc80c --show-standard-json-input > etherscan.json


plume3-check-logic :; forge script scripts/CheckPoolLogic.sol:CheckPoolLogic --chain 98864 --rpc-url https://test-rpc.plumenetwork.xyz -vvvv