// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '../../dependencies/openzeppelin/contracts/ERC4626.sol';
import '../../dependencies/openzeppelin/contracts/Math.sol';
import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/Ownable.sol';
import '../../interfaces/IPool.sol';
import '../../dependencies/chainlink/AggregatorInterface.sol';
import '../../interfaces/IAaveVault.sol';

contract AaveVault is ERC4626, Ownable, IAaveVault {
  mapping(address => mapping(address => AssetAllocation)) public assetAllocations;
  mapping(address => address[]) public poolAssets;
  address[] public aavePools;
  mapping(address => bool) public curators;
  mapping(address => WithdrawalRequest) public withdrawalRequests;

  uint256 public constant PERCENTAGE_SCALE = 10000;
  uint256 public withdrawalTimelock;
  uint256 public maxDeposit_;
  uint256 public maxWithdrawal_;
  uint256 public fee; // Fee in basis points (1/10000)
  address public feeRecipient;

  event CuratorAdded(address curator);
  event CuratorRemoved(address curator);
  event AssetAllocationAdded(address asset, address aavePool, uint256 allocationPercentage);
  event AssetAllocationUpdated(address asset, address aavePool, uint256 newAllocationPercentage);
  event AavePoolAdded(address aavePool);
  event Rebalanced();
  event FeeAccrued(uint256 amount);
  event FeesWithdrawn(uint256 amount);

  constructor(
    address baseAsset,
    uint256 _withdrawalTimelock,
    address _initialOwner,
    address _initialCurator,
    uint256 _maxDeposit,
    uint256 _maxWithdrawal,
    uint256 _fee,
    address _feeRecipient,
    string memory name,
    string memory symbol
  ) ERC4626(IERC20(baseAsset)) ERC20(name, symbol) {
    curators[_initialCurator] = true;
    withdrawalTimelock = _withdrawalTimelock;
    maxDeposit_ = _maxDeposit;
    maxWithdrawal_ = _maxWithdrawal;
    fee = _fee;
    feeRecipient = _feeRecipient;

    _transferOwnership(_initialOwner);
  }

  modifier onlyCurator() {
    require(curators[msg.sender], 'Not a curator');
    _;
  }

  modifier onlyCuratorOrOwner() {
    require(curators[msg.sender] || msg.sender == owner(), 'Not a curator');
    _;
  }

  function addCurator(address curator) external onlyCurator {
    curators[curator] = true;
    emit CuratorAdded(curator);
  }

  function removeCurator(address curator) external onlyCurator {
    curators[curator] = false;
    emit CuratorRemoved(curator);
  }

  function addAavePool(
    address newAsset,
    address aToken,
    address oracle,
    uint256 allocationPercentage,
    address aavePoolAddress
  ) external onlyCurator {
    _addAavePool(aavePoolAddress);
    addAssetAllocation(newAsset, aToken, oracle, allocationPercentage, aavePoolAddress);
  }

  function _addAavePool(address aavePoolAddress) internal {
    require(aavePoolAddress != address(0), 'Pool address cannot be zero');
    require(!_isAavePoolAdded(aavePoolAddress), 'Aave pool already added');
    aavePools.push(aavePoolAddress);
    emit AavePoolAdded(aavePoolAddress);
  }

  function addAssetAllocation(
    address newAsset,
    address aToken,
    address oracle,
    uint256 allocationPercentage,
    address aavePoolAddress
  ) public onlyCurator {
    require(newAsset != address(0), 'Asset address cannot be zero');
    require(aToken != address(0), 'AToken address cannot be zero');
    require(oracle != address(0), 'Oracle address cannot be zero');
    require(aavePoolAddress != address(0), 'Pool address cannot be zero');
    require(allocationPercentage != 0, 'Allocation Percentage cannot be zero');

    if (assetAllocations[aavePoolAddress][newAsset].allocationPercentage > 0) {
      updateAssetAllocation(newAsset, aavePoolAddress, allocationPercentage);
    } else {
      require(
        allocationPercentage <= PERCENTAGE_SCALE && allocationPercentage > 0,
        'Allocation must be <= 100%'
      );
      require(_isAavePoolAdded(aavePoolAddress), 'Aave pool not added');
      require(
        _checkTotalAllocation(newAsset, aavePoolAddress, allocationPercentage),
        'Total allocation exceeds 100%'
      );

      require(newAsset == asset(), 'asset does not match base asset');
      assetAllocations[aavePoolAddress][newAsset] = AssetAllocation({
        asset: newAsset,
        aToken: aToken,
        oracle: oracle,
        allocationPercentage: allocationPercentage
      });

      if (!_isAssetInPool(newAsset, aavePoolAddress)) {
        poolAssets[aavePoolAddress].push(newAsset);
        // we expect one asset per aavePoolAddress so one in the array
      }

      IERC20(newAsset).approve(aavePoolAddress, type(uint256).max);
      emit AssetAllocationAdded(newAsset, aavePoolAddress, allocationPercentage);
    }
  }

  function updateAssetAllocation(
    address updateAsset,
    address aavePoolAddress,
    uint256 newAllocationPercentage
  ) public onlyCurator {
    require(
      newAllocationPercentage <= PERCENTAGE_SCALE && newAllocationPercentage > 0,
      'Allocation must be <= 100%'
    );
    require(_isAavePoolAdded(aavePoolAddress), 'Aave pool not added');
    require(
      _checkTotalAllocation(updateAsset, aavePoolAddress, newAllocationPercentage),
      'Total allocation exceeds 100%'
    );
    require(updateAsset == asset(), 'asset does not match base asset');

    assetAllocations[aavePoolAddress][updateAsset].allocationPercentage = newAllocationPercentage;
    emit AssetAllocationUpdated(updateAsset, aavePoolAddress, newAllocationPercentage);
  }

  function reallocate(
    address asset,
    address aavePoolAddress,
    uint256 newAllocationPercentage
  ) external onlyCurator {
    updateAssetAllocation(asset, aavePoolAddress, newAllocationPercentage);
    _rebalance();
  }

  function _checkTotalAllocation(
    address asset,
    address aavePoolAddress,
    uint256 newAllocation
  ) internal view returns (bool) {
    uint256 totalAllocation = newAllocation;
    for (uint256 i = 0; i < poolAssets[aavePoolAddress].length; i++) {
      address currentAsset = poolAssets[aavePoolAddress][i];
      if (currentAsset != asset) {
        totalAllocation += assetAllocations[aavePoolAddress][currentAsset].allocationPercentage;
      }
    }
    return totalAllocation <= PERCENTAGE_SCALE;
  }

  function _isAssetInPool(address asset, address aavePoolAddress) internal view returns (bool) {
    for (uint256 i = 0; i < poolAssets[aavePoolAddress].length; i++) {
      if (poolAssets[aavePoolAddress][i] == asset) {
        return true;
      }
    }
    return false;
  }

  function _isAavePoolAdded(address aavePoolAddress) internal view returns (bool) {
    for (uint256 i = 0; i < aavePools.length; i++) {
      if (aavePools[i] == aavePoolAddress) {
        return true;
      }
    }
    return false;
  }

  function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
    uint256 total = 0;
    for (uint256 i = 0; i < aavePools.length; i++) {
      address aavePool = aavePools[i];
      for (uint256 j = 0; j < poolAssets[aavePool].length; j++) {
        address asset = poolAssets[aavePool][j];
        AssetAllocation memory allocation = assetAllocations[aavePool][asset];
        uint256 balance = IERC20(allocation.asset).balanceOf(address(this)) +
          IERC20(allocation.aToken).balanceOf(address(this));
        total += _convertToUsd(balance, allocation.oracle);
      }
    }
    return total;
  }

  function maxDeposit(address) public view override(ERC4626, IAaveVault) returns (uint256) {
    return maxDeposit_;
  }

  function maxMint(address) public view override(ERC4626, IERC4626) returns (uint256) {
    return _convertToShares(maxDeposit_, Math.Rounding.Floor);
  }

  function maxWithdrawal(address owner) public view override returns (uint256) {
    return maxWithdrawal_;
  }

  function maxRedeem(address owner) public view override(ERC4626, IERC4626) returns (uint256) {
    return _convertToShares(maxWithdraw(owner), Math.Rounding.Floor);
  }

  function deposit(
    uint256 assets,
    address receiver
  ) public override(ERC4626, IERC4626) returns (uint256) {
    require(assets <= maxDeposit_, 'Deposit amount exceeds maximum');
    return super.deposit(assets, receiver);
  }

  function mint(
    uint256 shares,
    address receiver
  ) public override(ERC4626, IERC4626) returns (uint256) {
    uint256 assets = _convertToAssets(shares, Math.Rounding.Ceil);
    require(assets <= maxDeposit_, 'Mint amount exceeds maximum deposit');
    return super.mint(shares, receiver);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override(ERC4626, IERC4626) returns (uint256) {
    require(assets <= maxWithdrawal_, 'Withdrawal amount exceeds maximum');
    require(
      withdrawalRequests[owner].requestTime + withdrawalTimelock <= block.timestamp,
      'Withdrawal timelock not met'
    );
    delete withdrawalRequests[owner];
    uint withdrawAsset = accrueFees(assets);
    return super.withdraw(withdrawAsset, receiver, owner);
  }

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override(ERC4626, IERC4626) returns (uint256) {
    uint256 assets = _convertToAssets(shares, Math.Rounding.Ceil);
    require(assets <= maxWithdrawal_, 'Redeem amount exceeds maximum withdrawal');
    require(
      withdrawalRequests[owner].requestTime + withdrawalTimelock <= block.timestamp,
      'Withdrawal timelock not met'
    );
    delete withdrawalRequests[owner];
    uint withdrawShares = accrueFees(shares, 0);
    return super.redeem(withdrawShares, receiver, owner);
  }

  function requestWithdrawal(uint256 shares) external {
    require(balanceOf(msg.sender) >= shares, 'Insufficient balance');
    withdrawalRequests[msg.sender] = WithdrawalRequest({
      user: msg.sender,
      shares: shares,
      requestTime: block.timestamp
    });
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    super._deposit(caller, receiver, assets, shares);
    _rebalance();
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    _withdrawFromAave(assets);
    super._withdraw(caller, receiver, owner, assets, shares);
  }

  function _rebalance() internal {
    uint256 totalAssetsUsd = totalAssets();

    for (uint256 i = 0; i < aavePools.length; i++) {
      address aavePool = aavePools[i];
      for (uint256 j = 0; j < poolAssets[aavePool].length; j++) {
        address asset = poolAssets[aavePool][j];
        AssetAllocation memory allocation = assetAllocations[aavePool][asset];
        uint256 targetAllocationUsd = (totalAssetsUsd * allocation.allocationPercentage) /
          PERCENTAGE_SCALE;
        uint256 currentAllocationUsd = _convertToUsd(
          IERC20(allocation.asset).balanceOf(address(this)) +
            IERC20(allocation.aToken).balanceOf(address(this)),
          allocation.oracle
        );

        if (currentAllocationUsd < targetAllocationUsd) {
          uint256 amountToDepositUsd = targetAllocationUsd - currentAllocationUsd;
          uint256 amountToDeposit = _convertFromUsd(amountToDepositUsd, allocation.oracle);
          _depositToAave(aavePool, allocation, amountToDeposit);
        } else if (currentAllocationUsd > targetAllocationUsd) {
          uint256 amountToWithdrawUsd = currentAllocationUsd - targetAllocationUsd;
          uint256 amountToWithdraw = _convertFromUsd(amountToWithdrawUsd, allocation.oracle);
          _withdrawFromAavePool(aavePool, allocation, amountToWithdraw);
        }
      }
    }

    emit Rebalanced();
  }

  function _depositToAave(
    address aavePool,
    AssetAllocation memory allocation,
    uint256 amount
  ) internal {
    IERC20(allocation.asset).approve(aavePool, amount);
    IPool(aavePool).supply(allocation.asset, amount, address(this), 0);
  }

  function _withdrawFromAave(uint256 assetsUsd) internal {
    for (uint256 i = 0; i < aavePools.length; i++) {
      address aavePool = aavePools[i];
      for (uint256 j = 0; j < poolAssets[aavePool].length; j++) {
        address asset = poolAssets[aavePool][j];
        AssetAllocation memory allocation = assetAllocations[aavePool][asset];
        uint256 aTokenBalance = IERC20(allocation.aToken).balanceOf(address(this));
        uint256 aTokenBalanceUsd = _convertToUsd(aTokenBalance, allocation.oracle);

        if (aTokenBalanceUsd > 0) {
          uint256 amountToWithdrawUsd = aTokenBalanceUsd < assetsUsd ? aTokenBalanceUsd : assetsUsd;
          uint256 amountToWithdraw = _convertFromUsd(amountToWithdrawUsd, allocation.oracle);
          IPool(aavePool).withdraw(allocation.asset, amountToWithdraw, address(this));
          assetsUsd -= amountToWithdrawUsd;

          if (assetsUsd == 0) break;
        }
      }
      if (assetsUsd == 0) break;
    }
  }

  function _withdrawFromAavePool(
    address aavePool,
    AssetAllocation memory allocation,
    uint256 amount
  ) internal {
    IPool(aavePool).withdraw(allocation.asset, amount, address(this));
  }

  function _convertToUsd(uint256 amount, address oracle) internal view returns (uint256) {
    // (, int256 price, , , ) = AggregatorInterface(oracle).latestRoundData();
    int256 price = AggregatorInterface(oracle).latestAnswer();
    return (amount * uint256(price)) / 1e8; // Assuming 8 decimal places for price feed
  }

  function _convertFromUsd(uint256 amountUsd, address oracle) internal view returns (uint256) {
    int256 price = AggregatorInterface(oracle).latestAnswer();
    return (amountUsd * 1e8) / uint256(price); // Assuming 8 decimal places for price feed
  }

  function accrueFees() internal returns (uint256 remaining) {
    uint256 totalAssetValue = totalAssets();
    uint256 feeAmount = (totalAssetValue * fee) / PERCENTAGE_SCALE;
    uint256 feeShares = _convertToShares(feeAmount, Math.Rounding.Floor);
    _mint(feeRecipient, feeShares);
    emit FeeAccrued(feeAmount);
  }

  function accrueFees(uint totalAssetValue) internal returns (uint256 remaining) {
    uint256 feeAmount = (totalAssetValue * fee) / PERCENTAGE_SCALE;
    uint256 feeShares = _convertToShares(feeAmount, Math.Rounding.Floor);
    _mint(feeRecipient, feeShares);
    emit FeeAccrued(feeAmount);

    return totalAssetValue - feeAmount;
  }

  function accrueFees(uint shares, uint) internal returns (uint256 remaining) {
    //trigger function overload without extra params
    uint256 feeShares = (shares * fee) / PERCENTAGE_SCALE;
    uint256 feeAmount = _convertToAssets(feeShares, Math.Rounding.Floor);
    _mint(feeRecipient, feeShares);
    emit FeeAccrued(feeAmount);

    return shares - feeShares;
  }

  function withdrawFees() external {
    require(msg.sender == feeRecipient, 'Only fee recipient can withdraw fees');
    uint256 feeShares = balanceOf(feeRecipient);
    uint256 feeAssets = _convertToAssets(feeShares, Math.Rounding.Floor);
    _burn(feeRecipient, feeShares);
    IERC20(asset()).transfer(feeRecipient, feeAssets);
    emit FeesWithdrawn(feeAssets);
  }

  function simulateWithdrawal(uint256 assets) external view returns (uint256) {
    return _convertToShares(assets, Math.Rounding.Floor);
  }

  function simulateSupply(uint256 assets) external view returns (uint256) {
    return _convertToShares(assets, Math.Rounding.Floor);
  }

  function _isAssetAndPoolSupported(address asset, address aavePool) internal view returns (bool) {
    return assetAllocations[aavePool][asset].asset != address(0);
  }
  
  function getAavePools() external view returns (address[] memory) {
    return aavePools;
  }

  function getPoolAssets(address aavePool) external view returns (address[] memory) {
    return poolAssets[aavePool];
  }

  function getTotalAllocation(address aavePool) public view returns (uint256) {
    uint256 totalAllocation = 0;
    for (uint256 i = 0; i < poolAssets[aavePool].length; i++) {
      address asset = poolAssets[aavePool][i];
      totalAllocation += assetAllocations[aavePool][asset].allocationPercentage;
    }
    return totalAllocation;
  }

  function setWithdrawalTimelock(uint256 newTimelock) external onlyCuratorOrOwner {
    withdrawalTimelock = newTimelock;
  }

  function setMaxDeposit(uint256 newMaxDeposit) external onlyCuratorOrOwner {
    maxDeposit_ = newMaxDeposit;
  }

  function setMaxWithdrawal(uint256 newMaxWithdrawal) external onlyCuratorOrOwner {
    maxWithdrawal_ = newMaxWithdrawal;
  }

  function setFee(uint256 newFee) external onlyOwner {
    require(newFee <= PERCENTAGE_SCALE / 2, 'Fee cannot exceed 50%');
    fee = newFee;
  }

  function setFeeRecipient(address newFeeRecipient) external onlyOwner {
    require(newFeeRecipient != address(0), 'Invalid fee recipient');
    feeRecipient = newFeeRecipient;
  }
}
