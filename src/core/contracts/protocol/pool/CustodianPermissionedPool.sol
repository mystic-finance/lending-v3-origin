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
abstract contract CustodianPermissionedPool is Pool, IL2Pool {
  using SafeERC20 for IERC20;
  mapping(address => bool) custodiedTokens;
  address public custodian;

  /**
   * @dev Only approved liquidator can call functions marked by this modifier.
   */
  modifier onlyLiquidator() {
    _onlyLiquidator();
    _;
  }

  /**
   * @dev Only pool user can call functions marked by this modifier.
   */
  modifier onlyPoolUser() {
    _onlyPoolUser();
    _;
  }

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider contract
   */
  constructor(IPoolAddressesProvider provider) Pool(provider) {}

  function _onlyPoolUser() internal view virtual {
    require(
      IACLManager(ADDRESSES_PROVIDER.getACLManager()).isPoolUser(msg.sender),
      Errors.CALLER_NOT_POOL_ADMIN
    );
  }

  function _onlyLiquidator() internal view virtual {
    require(
      IACLManager(ADDRESSES_PROVIDER.getACLManager()).isLiquidator(msg.sender),
      Errors.CALLER_NOT_POOL_ADMIN
    );
  }

  function updateCustodiedToken(address token, bool approved) external onlyPoolAdmin {
    custodiedTokens[token] = approved;
  }

  function updateCustodian(address newCustodian) external onlyPoolAdmin {
    custodian = newCustodian;
  }

  /// @inheritdoc IL2Pool
  function supply(bytes32 args) external override {
    (address asset, uint256 amount, uint16 referralCode) = CalldataLogic.decodeSupplyParams(
      _reservesList,
      args
    );

    supply(asset, amount, msg.sender, referralCode);

    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }
  }

  /// @inheritdoc IL2Pool
  function supplyWithPermit(bytes32 args, bytes32 r, bytes32 s) external override {
    (address asset, uint256 amount, uint16 referralCode, uint256 deadline, uint8 v) = CalldataLogic
      .decodeSupplyWithPermitParams(_reservesList, args);

    supplyWithPermit(asset, amount, msg.sender, referralCode, deadline, v, r, s);

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
    return withdraw(asset, amount, msg.sender);
  }

  function withdraw(address asset, uint256 amount, address to) public override returns (uint256) {
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransferFrom(custodian, address(this), amount);
    }
    return super.withdraw(asset, amount, to);
  }

  /// @inheritdoc IL2Pool
  function borrow(bytes32 args) external override onlyPoolUser {
    (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode) = CalldataLogic
      .decodeBorrowParams(_reservesList, args);

    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransferFrom(custodian, address(this), amount);
    }
    borrow(asset, amount, interestRateMode, referralCode, msg.sender);
  }

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) public override onlyPoolUser {
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransferFrom(custodian, address(this), amount);
    }
    super.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
  }

  /// @inheritdoc IL2Pool
  function repay(bytes32 args) external override onlyPoolUser returns (uint256) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    uint256 repaid = repay(asset, amount, interestRateMode, msg.sender);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
  }

  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) public override onlyPoolUser returns (uint256) {
    uint256 repaid = super.repay(asset, amount, interestRateMode, onBehalfOf);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
  }

  /// @inheritdoc IL2Pool
  function repayWithPermit(
    bytes32 args,
    bytes32 r,
    bytes32 s
  ) external override onlyPoolUser returns (uint256) {
    (
      address asset,
      uint256 amount,
      uint256 interestRateMode,
      uint256 deadline,
      uint8 v
    ) = CalldataLogic.decodeRepayWithPermitParams(_reservesList, args);

    uint256 repaid = repayWithPermit(
      asset,
      amount,
      interestRateMode,
      msg.sender,
      deadline,
      v,
      r,
      s
    );
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
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
  ) public override onlyPoolUser returns (uint256) {
    uint256 repaid = super.repayWithPermit(
      asset,
      amount,
      interestRateMode,
      onBehalfOf,
      deadline,
      permitV,
      permitR,
      permitS
    );

    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
  }

  /// @inheritdoc IL2Pool
  function repayWithATokens(bytes32 args) external override onlyPoolUser returns (uint256) {
    (address asset, uint256 amount, uint256 interestRateMode) = CalldataLogic.decodeRepayParams(
      _reservesList,
      args
    );

    uint256 repaid = repayWithATokens(asset, amount, interestRateMode);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
  }

  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) public override onlyPoolUser returns (uint256) {
    uint256 repaid = super.repayWithATokens(asset, amount, interestRateMode);
    if (custodiedTokens[asset] && custodian != address(0)) {
      IERC20(asset).safeTransfer(custodian, amount);
    }

    return repaid;
  }

  function swapBorrowRateMode(
    address asset,
    uint256 interestRateMode
  ) public override onlyPoolUser {
    super.swapBorrowRateMode(asset, interestRateMode);
  }

  /// @inheritdoc IL2Pool
  function swapBorrowRateMode(bytes32 args) external override onlyPoolUser {
    (address asset, uint256 interestRateMode) = CalldataLogic.decodeSwapBorrowRateModeParams(
      _reservesList,
      args
    );
    swapBorrowRateMode(asset, interestRateMode);
  }

  /// @inheritdoc IL2Pool
  function rebalanceStableBorrowRate(bytes32 args) external override onlyPoolUser {
    (address asset, address user) = CalldataLogic.decodeRebalanceStableBorrowRateParams(
      _reservesList,
      args
    );
    rebalanceStableBorrowRate(asset, user);
  }

  function rebalanceStableBorrowRate(address asset, address user) public override onlyPoolUser {
    super.rebalanceStableBorrowRate(asset, user);
  }

  /// @inheritdoc IL2Pool
  function setUserUseReserveAsCollateral(bytes32 args) external override onlyPoolUser {
    (address asset, bool useAsCollateral) = CalldataLogic.decodeSetUserUseReserveAsCollateralParams(
      _reservesList,
      args
    );
    setUserUseReserveAsCollateral(asset, useAsCollateral);
  }

  function setUserUseReserveAsCollateral(
    address asset,
    bool useAsCollateral
  ) public override onlyPoolUser {
    super.setUserUseReserveAsCollateral(asset, useAsCollateral);
  }

  /// @inheritdoc IL2Pool
  function liquidationCall(bytes32 args1, bytes32 args2) external override onlyLiquidator {
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
  ) public override onlyLiquidator {
    super.liquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
  }
}
