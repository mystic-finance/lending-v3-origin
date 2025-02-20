// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TrancheRouter} from './TranchRouter.sol';
import {Pool} from 'src/core/contracts/protocol/pool/Pool.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {IL2Pool} from '../../interfaces/IL2Pool.sol';
import {CalldataLogic} from '../libraries/logic/CalldataLogic.sol';

abstract contract HookedAavePool is Pool, IL2Pool {
  TrancheRouter public immutable trancheRouter;

  constructor(address _router, IPoolAddressesProvider provider) Pool(provider) {
    trancheRouter = TrancheRouter(_router);
  }

  // Hooks for all liquidity operations
  modifier withHooks(
    address asset,
    uint256 amount,
    bool isDebtOperation,
    bool skip
  ) {
    if (!skip) _beforeHook(asset, amount);
    _;
    if (isDebtOperation) _afterHook(asset);
  }

  function _beforeHook(address asset, uint256 amount) internal {
    trancheRouter.beforeLiquidityOperation(asset, amount);
  }

  function _afterHook(address asset) internal {
    trancheRouter.afterDebtOperation(asset);
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) public override withHooks(asset, amount, false, true) {
    _beforeHook(asset, 0);
    super.supply(asset, amount, onBehalfOf, referralCode);
  }

  /// @inheritdoc IL2Pool
  function supply(bytes32 args) external override {
    (address asset, uint256 amount, uint16 referralCode) = CalldataLogic.decodeSupplyParams(
      _reservesList,
      args
    );

    supply(asset, amount, msg.sender, referralCode);
  }

  /// @inheritdoc IL2Pool
  function supplyWithPermit(bytes32 args, bytes32 r, bytes32 s) public override {
    (address asset, uint256 amount, uint16 referralCode, uint256 deadline, uint8 v) = CalldataLogic
      .decodeSupplyWithPermitParams(_reservesList, args);

    supplyWithPermit(asset, amount, msg.sender, referralCode, deadline, v, r, s);
  }

  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override withHooks(asset, amount, false, true) {
    _beforeHook(asset, 0);
    super.supplyWithPermit(asset, amount, msg.sender, referralCode, deadline, v, r, s);
  }

  /// @inheritdoc IL2Pool
  function withdraw(bytes32 args) external override returns (uint256) {
    (address asset, uint256 amount) = CalldataLogic.decodeWithdrawParams(_reservesList, args);

    return withdraw(asset, amount, msg.sender);
  }

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) public override withHooks(asset, amount, false, false) returns (uint256) {
    return super.withdraw(asset, amount, to);
  }

  /// @inheritdoc IL2Pool
  function borrow(bytes32 args) external override {
    (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode) = CalldataLogic
      .decodeBorrowParams(_reservesList, args);

    borrow(asset, amount, interestRateMode, referralCode, msg.sender);
  }

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) public override withHooks(asset, amount, true, false) {
    super.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
  }

  /// @inheritdoc IL2Pool
  function repay(bytes32 args) external override returns (uint256) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    return repay(asset, amount, interestRateMode, msg.sender);
  }

  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) public override withHooks(asset, amount, true, false) returns (uint256) {
    return super.repay(asset, amount, interestRateMode, onBehalfOf);
  }

  /// @inheritdoc IL2Pool
  function repayWithPermit(bytes32 args, bytes32 r, bytes32 s) external override returns (uint256) {
    (
      address asset,
      uint256 amount,
      uint256 interestRateMode,
      uint256 deadline,
      uint8 v
    ) = CalldataLogic.decodeRepayWithPermitParams(_reservesList, args);

    return repayWithPermit(asset, amount, interestRateMode, msg.sender, deadline, v, r, s);
  }

  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) public override withHooks(asset, amount, true, false) returns (uint256) {
    return
      super.repayWithPermit(
        asset,
        amount,
        interestRateMode,
        onBehalfOf,
        deadline,
        permitV,
        permitR,
        permitS
      );
  }

  /// @inheritdoc IL2Pool
  function repayWithATokens(bytes32 args) external override returns (uint256) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    return repayWithATokens(asset, amount, interestRateMode);
  }

  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) public override withHooks(asset, amount, true, false) returns (uint256) {
    return super.repayWithATokens(asset, amount, interestRateMode);
  }

  /// @inheritdoc IL2Pool
  function liquidationCall(bytes32 args1, bytes32 args2) external override {
    (
      address collateralAsset,
      address debtAsset,
      address user,
      uint256 debtToCover,
      bool receiveAToken
    ) = CalldataLogic.decodeLiquidationCallParams(_reservesList, args1, args2);
    liquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
  }

  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) public override withHooks(debtAsset, debtToCover, true, false) {
    super.liquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
  }
}

// add supply, withdraw, borrow and repay with permits and repay with atoken
