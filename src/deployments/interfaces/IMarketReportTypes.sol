// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import 'src/core/contracts/interfaces/IPoolAddressesProvider.sol';
import 'src/core/contracts/interfaces/IPoolAddressesProviderRegistry.sol';
import 'src/core/contracts/interfaces/IPool.sol';
import 'src/core/contracts/interfaces/IPoolConfigurator.sol';
import 'src/core/contracts/interfaces/IAaveOracle.sol';
import 'src/core/contracts/interfaces/IAToken.sol';
import 'src/core/contracts/interfaces/IVariableDebtToken.sol';
import 'src/core/contracts/interfaces/IStableDebtToken.sol';
import 'src/core/contracts/interfaces/IACLManager.sol';
import 'src/core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import 'src/core/contracts/misc/AaveProtocolDataProvider.sol';
import 'src/periphery/contracts/misc/UiPoolDataProviderV3.sol';
import 'src/periphery/contracts/misc/UiIncentiveDataProviderV3.sol';
import 'src/periphery/contracts/rewards/interfaces/IEmissionManager.sol';
import 'src/periphery/contracts/rewards/interfaces/IRewardsController.sol';
import 'src/periphery/contracts/misc/WalletBalanceProvider.sol';
import 'src/periphery/contracts/adapters/paraswap/ParaSwapLiquiditySwapAdapter.sol';
import 'src/periphery/contracts/adapters/paraswap/ParaSwapRepayAdapter.sol';
import 'src/periphery/contracts/adapters/paraswap/ParaSwapWithdrawSwapAdapter.sol';
import 'src/periphery/contracts/misc/interfaces/IWrappedTokenGatewayV3.sol';
import 'src/core/contracts/misc/L2Encoder.sol';
import {IAaveV3ConfigEngine} from 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {ICollector} from 'src/periphery/contracts/treasury/ICollector.sol';
import {ProxyAdmin} from 'lib/solidity-utils/src/contracts/transparent-proxy/ProxyAdmin.sol';

struct ContractsReport {
  IPoolAddressesProviderRegistry poolAddressesProviderRegistry;
  IPoolAddressesProvider poolAddressesProvider;
  IPool poolProxy;
  IPool poolImplementation;
  IPoolConfigurator poolConfiguratorProxy;
  IPoolConfigurator poolConfiguratorImplementation;
  AaveProtocolDataProvider protocolDataProvider;
  IAaveOracle aaveOracle;
  IACLManager aclManager;
  ICollector treasury;
  IDefaultInterestRateStrategyV2 defaultInterestRateStrategyV2;
  ProxyAdmin proxyAdmin;
  ICollector treasuryImplementation;
  IWrappedTokenGatewayV3 wrappedTokenGateway;
  WalletBalanceProvider walletBalanceProvider;
  UiIncentiveDataProviderV3 uiIncentiveDataProvider;
  UiPoolDataProviderV3 uiPoolDataProvider;
  ParaSwapLiquiditySwapAdapter paraSwapLiquiditySwapAdapter;
  ParaSwapRepayAdapter paraSwapRepayAdapter;
  ParaSwapWithdrawSwapAdapter paraSwapWithdrawSwapAdapter;
  L2Encoder l2Encoder;
  IAToken aToken;
  IVariableDebtToken variableDebtToken;
  IStableDebtToken stableDebtToken;
  IEmissionManager emissionManager;
  IRewardsController rewardsControllerImplementation;
  IRewardsController rewardsControllerProxy;
}

struct MarketReport {
  address poolAddressesProviderRegistry;
  address poolAddressesProvider;
  address poolProxy;
  address poolImplementation;
  address poolConfiguratorProxy;
  address poolConfiguratorImplementation;
  address protocolDataProvider;
  address aaveOracle;
  address defaultInterestRateStrategyV2;
  address aclManager;
  address treasury;
  address proxyAdmin;
  address treasuryImplementation;
  address wrappedTokenGateway;
  address walletBalanceProvider;
  address uiIncentiveDataProvider;
  address uiPoolDataProvider;
  address paraSwapLiquiditySwapAdapter;
  address paraSwapRepayAdapter;
  address paraSwapWithdrawSwapAdapter;
  address aaveParaSwapFeeClaimer;
  address l2Encoder;
  address aToken;
  address variableDebtToken;
  address stableDebtToken;
  address emissionManager;
  address rewardsControllerImplementation;
  address rewardsControllerProxy;
  address kycPortal;
  address timelock;
  address engine;
}

struct LibrariesReport {
  address borrowLogic;
  address bridgeLogic;
  address configuratorLogic;
  address eModeLogic;
  address flashLoanLogic;
  address liquidationLogic;
  address poolLogic;
  address supplyLogic;
}

struct Roles {
  address marketOwner;
  address poolAdmin;
  address emergencyAdmin;
}

struct MarketConfig {
  address networkBaseTokenPriceInUsdProxyAggregator;
  address marketReferenceCurrencyPriceInUsdProxyAggregator;
  string marketId;
  uint8 oracleDecimals;
  address paraswapAugustusRegistry;
  address paraswapFeeClaimer;
  uint256 providerId;
  bytes32 salt;
  address wrappedNativeToken;
  address proxyAdmin;
  uint128 flashLoanPremiumTotal;
  uint128 flashLoanPremiumToProtocol;
  uint8 poolType;
}

struct SubMarketConfig {
  address timelock;
  address kycPortal;
  address underlyingAsset;
  address debtAsset;
  address create2_factory;
}

struct ListingConfig {
  IAaveV3ConfigEngine.Listing[] listings;
  IAaveV3ConfigEngine.Listing[] listingBorrow;
  IAaveV3ConfigEngine.CollateralUpdate collateralUpdate;
  IAaveV3ConfigEngine.BorrowUpdate borrowUpdate;
  IAaveV3ConfigEngine.PoolContext poolContext;
  address treasury;
  address interestRateStrategy;
  address poolConfigurator;
  address rewardsController;
  address poolProxy;
  address oracle;
}

struct DeployFlags {
  bool l2;
}

struct PoolReport {
  address poolImplementation;
  address poolConfiguratorImplementation;
  address kycPortal;
  address timelock;
}

struct PartnerReport {
  address kycPortal;
  address timelock;
}

struct InitialReport {
  address poolAddressesProvider;
  address poolAddressesProviderRegistry;
}

struct SetupReport {
  address poolProxy;
  address poolConfiguratorProxy;
  address rewardsControllerProxy;
  address aclManager;
}

struct PeripheryReport {
  address aaveOracle;
  address proxyAdmin;
  address treasury;
  address treasuryImplementation;
  address emissionManager;
  address rewardsControllerImplementation;
  address defaultInterestRateStrategyV2;
}

struct ParaswapReport {
  address paraSwapLiquiditySwapAdapter;
  address paraSwapRepayAdapter;
  address paraSwapWithdrawSwapAdapter;
  address aaveParaSwapFeeClaimer;
}
