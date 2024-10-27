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

deploy-script-test-arb-sepolia :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --verify --slow  -vvv --with-gas-price 200000000 --gas-estimate-multiplier 150 --delay 5
deploy-script-plume-devnet3 :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --verifier blockscout --verifier-url https://test-explorer.plumenetwork.xyz/api --legacy --gas-estimate-multiplier 5000 --delay 5
deploy-script-plume-devnet :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
deploy-script-test-polygon :; forge script scripts/DeployAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --verify --legacy --delay 5 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv


deploy-list-asset-arb-sepolia :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 421614 --rpc-url arb_sepolia --broadcast --slow --verify -vvv --with-gas-price 200000000  --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-plume :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --slow --sender 0x4C741E7f98B166286157940Bc7bb86EBaEC51D0a --delay 5
deploy-list-asset-plume2 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --delay 5
deploy-list-asset-plume3 :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --delay 5 --gas-estimate-multiplier 5000
deploy-list-asset-plume-verify :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 161221135 --rpc-url plume --broadcast --legacy --slow --verifier blockscout --verifier-url https://plume-testnet.explorer.caldera.xyz/api --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5
deploy-list-asset-polygon :; forge script scripts/ListAaveV3MarketBatched.sol:Default --chain 137 --rpc-url polygon --broadcast --slow --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 --delay 5 -vvv


# deploy-aave-bundler-plume :; forge script scripts/DeployAaveBundler.sol:Default --chain 161221135 --rpc-url plume --broadcast --force  -vvvv --gas-estimate-multiplier 150 --sender 0x0fbAecF514Ab7145e514ad4c448f417BE9292D63 -vvv
deploy-aave-vault-plume-devnet :; forge script scripts/DeployAaveVault.sol:Default --chain 18230 --rpc-url plume2 --broadcast --slow --legacy --gas-estimate-multiplier 150 --delay 5
deploy-aave-vault-plume-testnet :; forge script scripts/DeployAaveVault.sol:Default --chain 98864 --rpc-url plume3 --broadcast --slow --legacy --gas-estimate-multiplier 5000 --delay 5

