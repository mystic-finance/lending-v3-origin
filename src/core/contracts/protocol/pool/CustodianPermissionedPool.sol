// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {Pool} from './Pool.sol';
import {SemiPermissionedPool} from './SemiPermissionedPool.sol';
import {IPoolAddressesProvider} from '../../interfaces/IPoolAddressesProvider.sol';
import {IL2Pool} from '../../interfaces/IL2Pool.sol';
import {CalldataLogic} from '../libraries/logic/CalldataLogic.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';

/**
 * @title L2Pool
 * @author Aave
 * @notice Calldata optimized extension of the Pool contract allowing users to pass compact calldata representation
 * to reduce transaction costs on rollups.
 */
abstract contract CustodianPermissionedPool is SemiPermissionedPool, Pool, IL2Pool {
  using SafeERC20 for IERC20;
  mapping(address => bool) custodiedTokens;
  address public custodian;
  /// @inheritdoc IL2Pool
  function supply(bytes32 args) external override {
    (address asset, uint256 amount, uint16 referralCode) = CalldataLogic.decodeSupplyParams(
      _reservesList,
      args
    );

    super.supply(args);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function supplyWithPermit(bytes32 args, bytes32 r, bytes32 s) external override {
    (address asset, uint256 amount, uint16 referralCode, uint256 deadline, uint8 v) = CalldataLogic
      .decodeSupplyWithPermitParams(_reservesList, args);

    super.supplyWithPermit(args, r, s);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function withdraw(bytes32 args) external override returns (uint256) {
    (address asset, uint256 amount) = CalldataLogic.decodeWithdrawParams(_reservesList, args);

    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransferFrom(custodian, address(this), amount);
    }

    return super.withdraw(args);
  }

  /// @inheritdoc IL2Pool
  function borrow(bytes32 args) external override {
    (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode) = CalldataLogic
      .decodeBorrowParams(_reservesList, args);

    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransferFrom(custodian, address(this), amount);
    }

    super.borrow(args);
  }

  /// @inheritdoc IL2Pool
  function repay(bytes32 args) external override returns (uint256 repaid) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    repaid = super.repay(args);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function repayWithPermit(
    bytes32 args,
    bytes32 r,
    bytes32 s
  ) external override returns (uint256 repaid) {
    (
      address asset,
      uint256 amount,
      uint256 interestRateMode,
      uint256 deadline,
      uint8 v
    ) = CalldataLogic.decodeRepayWithPermitParams(_reservesList, args);

    repaid = super.repayWithPermit(args, r, s);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function repayWithATokens(bytes32 args) external override returns (uint256 repaid) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    repaid = super.repayWithATokens(args);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function liquidationCall(bytes32 args1, bytes32 args2) external override onlyBondLiquidator {
    (
      address collateralAsset,
      address debtAsset,
      address user,
      uint256 debtToCover,
      bool receiveAToken
    ) = CalldataLogic.decodeLiquidationCallParams(_reservesList, args1, args2);
    liquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
  }
}
