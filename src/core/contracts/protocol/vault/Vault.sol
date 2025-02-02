// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '../../dependencies/openzeppelin/contracts/ERC4626.sol';
import '../../dependencies/openzeppelin/contracts/Math.sol';
import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import '../../dependencies/openzeppelin/contracts/Ownable.sol';
import '../../interfaces/IPool.sol';
import '../../dependencies/chainlink/AggregatorV3Interface.sol';
import '../../interfaces/IMysticVault.sol';
import '../../interfaces/ICreditDelegationToken.sol';

import {UserConfiguration} from 'src/core/contracts/protocol/libraries/configuration/UserConfiguration.sol';
import {ReserveConfiguration} from 'src/core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

contract MysticVault is ERC4626, Ownable, IMysticVault {
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using SafeERC20 for IERC20;

  mapping(address => mapping(address => AssetAllocation)) public assetAllocations;
  mapping(address => address[]) public poolAssets;
  address[] public mysticPools;
  mapping(address => bool) public curators;
  mapping(address => WithdrawalRequest) public withdrawalRequests;
  mapping(address => uint256) public lastValidPrice;

  struct APRData {
    uint256 supplyAPR;
    uint256 borrowAPR;
  }
  // Struct to cache deposit data
  struct DepositData {
      address mysticPool;
      AssetAllocation allocation;
      uint256 amountToDeposit;
  }

  // Array to store cached deposits
  DepositData[] depositsToProcess;
  uint256 public constant PERCENTAGE_SCALE = 10000;
  uint256 public constant priceFeedUpdateInterval = 3600; // 1 hour
  uint256 public withdrawalTimelock;
  uint256 public maxDeposit_;
  uint256 public maxWithdrawal_;
  uint256 public fee; // Fee in basis points (1/10000)
  address public feeRecipient;
  uint256 public totalDeposited;
  uint256 public totalBorrowed;

  event CuratorAdded(address curator);
  event CuratorRemoved(address curator);
  event AssetAllocationAdded(address asset, address mysticPool, uint256 allocationPercentage);
  event AssetAllocationUpdated(address asset, address mysticPool, uint256 newAllocationPercentage);
  event MysticPoolAdded(address mysticPool);
  event MysticPoolRemoved(address mysticPool);
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
    _mint(address(this), 1e18); // Mint initial shares to the vault
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

  function addMysticPool(
    address newAsset,
    address oracle,
    uint256 allocationPercentage,
    address mysticPoolAddress
  ) external onlyCurator {
    _addMysticPool(mysticPoolAddress);
    updateAssetAllocation(newAsset, oracle, allocationPercentage, mysticPoolAddress); // atoken is generated in updateAssetAllocation
  }

  function _addMysticPool(address mysticPoolAddress) internal {
    require(mysticPoolAddress != address(0), 'Pool address cannot be zero');
    require(!_isMysticPoolAdded(mysticPoolAddress), 'Mystic pool already added');
    mysticPools.push(mysticPoolAddress);
    emit MysticPoolAdded(mysticPoolAddress);
  }

  function _removeMysticPool(address mysticPoolAddress) internal {
    require(mysticPoolAddress != address(0), 'Pool address cannot be zero');
    uint idx = _mysticPoolIndex(mysticPoolAddress);
    mysticPools[idx] = mysticPools[mysticPools.length -1];
    mysticPools.pop();
    emit MysticPoolRemoved(mysticPoolAddress);
  }

  function updateAssetAllocation(
    address newAsset,
    address oracle,
    uint256 allocationPercentage,
    address mysticPoolAddress
  ) public onlyCurator {
    require(newAsset != address(0), 'Asset address cannot be zero');
    require(oracle != address(0), 'Oracle address cannot be zero');
    require(mysticPoolAddress != address(0), 'Pool address cannot be zero');

    address aToken = _getAssetATokenAddress(mysticPoolAddress);
    require(aToken != address(0), 'Asset not supported by pool');
    
    if (assetAllocations[mysticPoolAddress][newAsset].allocationPercentage > 0) {
      // update or remove pool by setting allocation% to zero
      _updateAssetAllocation(newAsset, mysticPoolAddress, allocationPercentage);
      _rebalance();
      if(allocationPercentage == 0){
        _removeMysticPool(mysticPoolAddress);
      }
    } else {
      // new pool addtion and allocation
      require(
        allocationPercentage <= PERCENTAGE_SCALE && allocationPercentage > 0,
        'Allocation must be <= 100%'
      );
      require(_isMysticPoolAdded(mysticPoolAddress), 'Mystic pool not added');
      require(
        _checkTotalAllocation(newAsset, allocationPercentage),
        'Total allocation exceeds 100%'
      );

      require(newAsset == asset(), 'asset does not match base asset');
      assetAllocations[mysticPoolAddress][newAsset] = AssetAllocation({
        asset: newAsset,
        aToken: aToken,
        oracle: oracle,
        allocationPercentage: allocationPercentage
      });

      if (!_isAssetInPool(newAsset, mysticPoolAddress)) {
        poolAssets[mysticPoolAddress].push(newAsset);
        // we expect one asset per mysticPoolAddress so one in the array
      }
      _rebalance();

      IERC20(newAsset).safeApprove(mysticPoolAddress, type(uint256).max);
      emit AssetAllocationAdded(newAsset, mysticPoolAddress, allocationPercentage);
    }
  }

  function _updateAssetAllocation(
    address updateAsset,
    address mysticPoolAddress,
    uint256 newAllocationPercentage
  ) internal {
    require(
      newAllocationPercentage <= PERCENTAGE_SCALE && newAllocationPercentage > 0,
      'Allocation must be <= 100%'
    );
    require(_isMysticPoolAdded(mysticPoolAddress), 'Mystic pool not added');
    require(
      _checkTotalAllocation(updateAsset, newAllocationPercentage),
      'Total allocation exceeds 100%'
    );
    require(updateAsset == asset(), 'asset does not match base asset');

    assetAllocations[mysticPoolAddress][updateAsset].allocationPercentage = newAllocationPercentage;
    emit AssetAllocationUpdated(updateAsset, mysticPoolAddress, newAllocationPercentage);
  }

  function reallocate(
    address asset,
    address mysticPoolAddress,
    uint256 newAllocationPercentage
  ) external onlyCurator {
    _updateAssetAllocation(asset, mysticPoolAddress, newAllocationPercentage);
    _rebalance();
  }


  function _checkTotalAllocation(
    address asset,
    uint256 newAllocation
  ) internal view returns (bool) {
      //allocation percentage is per asset, meaning usdc allocation must sum up to 100% for a set of pools, 
      // but same set of pools might have different allocations of eth summing up to 100 also
      uint256 totalAllocation = newAllocation;

      // Iterate through all pools to calculate the total allocation for the asset
      for (uint256 i = 0; i < mysticPools.length; i++) {
          address mysticPool = mysticPools[i];

          // Skip the current pool if the asset is not allocated in it
          if (!_isAssetInPool(asset, mysticPool)) {
              continue;
          }

          // Add the allocation for the asset in the current pool
          totalAllocation += assetAllocations[mysticPool][asset].allocationPercentage;
      }

      return totalAllocation <= PERCENTAGE_SCALE;
  }

  function _isAssetInPool(address asset, address mysticPoolAddress) internal view returns (bool) {
    for (uint256 i = 0; i < poolAssets[mysticPoolAddress].length; i++) {
      if (poolAssets[mysticPoolAddress][i] == asset) {
        return true;
      }
    }
    return false;
  }

  function _isMysticPoolAdded(address mysticPoolAddress) internal view returns (bool) {
    for (uint256 i = 0; i < mysticPools.length; i++) {
      if (mysticPools[i] == mysticPoolAddress) {
        return true;
      }
    }
    return false;
  }

  function _mysticPoolIndex(address mysticPoolAddress) internal view returns (uint256) {
    for (uint256 i = 0; i < mysticPools.length; i++) {
      if (mysticPools[i] == mysticPoolAddress) {
        return i;
      }
    }
    // it should fail if pool is large enough to reach uint256 mas
    return type(uint256).max - 1;
  }

  function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
    return totalDeposited;
  }

  function totalAssetsInUsd() public view returns (uint256) {
    // since all assets added from pools are expected to be same, there is no need to track deposits for each asset
    uint256 total = 0;
    address mysticPool = mysticPools[0];
    address asset = poolAssets[mysticPool][0];
    AssetAllocation memory allocation = assetAllocations[mysticPool][asset];
    total = _convertToUsd(totalDeposited, allocation.oracle);
    return total;
  }

  function maxDeposit(address) public view override(ERC4626, IMysticVault) returns (uint256) {
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

  function isApprovedCollateral(
    address collateralAsset,
    address user,
    address mysticPoolAddress
  ) public view returns (bool) {
    address[] memory reserves = IPool(mysticPoolAddress).getReservesList();
    DataTypes.UserConfigurationMap memory userConfig = IPool(mysticPoolAddress)
      .getUserConfiguration(user);

    for (uint256 i = 0; i < reserves.length; i++) {
      bool approvedCollateral = userConfig.isUsingAsCollateral(i);

      if (approvedCollateral) {
        return true;
      }
    }

    return false;
  }

  function borrow(
    address collateralAsset,
    uint256 collateralAmount,
    uint256 amount, //borrow amount
    address mysticPoolAddress,
    address receiver,
    bool receiveShares
  ) external {
    require(_isAssetAndPoolSupported(asset(), mysticPoolAddress), 'Asset or pool not supported');
    require(
      isApprovedCollateral(collateralAsset, msg.sender, mysticPoolAddress),
      'Collateral not supported'
    );

    // Get the variable debt token address
    address variableDebtTokenAddress = IPool(mysticPoolAddress)
      .getReserveData(asset())
      .variableDebtTokenAddress;
    ICreditDelegationToken variableDebtToken = ICreditDelegationToken(variableDebtTokenAddress);

    // deposit collateral if needed
    if (collateralAmount > 0) {
      IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
      IERC20(collateralAsset).safeApprove(mysticPoolAddress, collateralAmount);
      IPool(mysticPoolAddress).supply(collateralAsset, collateralAmount, msg.sender, 0);
    }

    // Check borrow allowance
    require(
      variableDebtToken.borrowAllowance(msg.sender, address(this)) >= amount,
      'Insufficient borrow allowance'
    );

    totalBorrowed += amount;

    // Proceed to borrow the specified amount
    if (receiveShares) {
      IPool(mysticPoolAddress).borrow(asset(), amount, 2, 0, msg.sender);
      deposit(amount, receiver);
    } else {
      IPool(mysticPoolAddress).borrow(asset(), amount, 2, 0, msg.sender);
      IERC20(asset()).safeTransfer(receiver, amount);
    }
  }

  function withdraw(
    uint256,
    address receiver,
    address owner
  ) public override(ERC4626, IERC4626) returns (uint256) {
    require(owner == msg.sender, 'owners must be sender');
    require(
      withdrawalRequests[owner].requestTime + withdrawalTimelock <= block.timestamp,
      'Withdrawal timelock not met'
    );

    uint256 assets = withdrawalRequests[owner].assets;
    delete withdrawalRequests[owner];
    uint withdrawAsset = accrueFees(assets);
    return super.withdraw(withdrawAsset, receiver, owner);
  }

  function redeem(
    uint256,
    address receiver,
    address owner
  ) public override(ERC4626, IERC4626) returns (uint256) {
    require(owner == msg.sender, 'owners must be sender');
    require(
      withdrawalRequests[owner].requestTime + withdrawalTimelock <= block.timestamp,
      'Withdrawal timelock not met'
    );

    uint256 assets = withdrawalRequests[owner].assets;
    uint shares = _convertToShares(assets, Math.Rounding.Floor);

    delete withdrawalRequests[owner];
    uint withdrawShares = accrueFees(shares, 0);
    return super.redeem(withdrawShares, receiver, owner);
  }

  function requestWithdrawal(uint256 assets) external {
    uint shares = _convertToShares(assets, Math.Rounding.Floor);
    require(balanceOf(msg.sender) >= shares, 'Insufficient balance');
    require(assets <= maxWithdrawal_, 'Withdrawal amount exceeds maximum');

    withdrawalRequests[msg.sender] = WithdrawalRequest({
      user: msg.sender,
      assets: assets,
      requestTime: block.timestamp
    });
  }

  function repay(uint256 amount, address mysticPoolAddress, address onBehalfOf) external {
    require(_isAssetAndPoolSupported(asset(), mysticPoolAddress), 'Asset or pool not supported');
    totalBorrowed -= amount;

    IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
    uint256 allowance = IERC20(asset()).allowance(address(this), mysticPoolAddress);
    if (allowance < amount) {
      IERC20(asset()).safeApprove(mysticPoolAddress, type(uint256).max);
    }

    IPool(mysticPoolAddress).repay(asset(), amount, 2, onBehalfOf);
  }

  function repayWithShares(uint256 shares, address mysticPoolAddress, address onBehalfOf) external {
    require(_isAssetAndPoolSupported(asset(), mysticPoolAddress), 'Asset or pool not supported');
    uint256 amount = convertToAssets(shares); //_convertToAssets(shares, Math.Rounding.Ceil);
    totalBorrowed -= amount;

    uint256 assets = convertToAssets(shares);
    _burn(msg.sender, shares);

    uint256 allowance = IERC20(asset()).allowance(address(this), mysticPoolAddress);
    if (allowance < amount) {
      IERC20(asset()).safeApprove(mysticPoolAddress, type(uint256).max);
    }

    IPool(mysticPoolAddress).repay(asset(), amount, 2, onBehalfOf);
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    super._deposit(caller, receiver, assets, shares);
    totalDeposited += assets;
    _rebalance();
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    _rebalance();
    _withdrawFromMystic(assets);
    super._withdraw(caller, receiver, owner, assets, shares);
    totalDeposited -= assets;
  }

  function _rebalance() internal {
    uint256 totalAssetsUsd = totalAssetsInUsd();

    

    // First pass: Process all withdrawals
    for (uint256 i = 0; i < mysticPools.length; i++) {
        address mysticPool = mysticPools[i];
        for (uint256 j = 0; j < poolAssets[mysticPool].length; j++) {
            address asset = poolAssets[mysticPool][j];
            AssetAllocation memory allocation = assetAllocations[mysticPool][asset];

            uint256 targetAllocationUsd = (totalAssetsUsd * allocation.allocationPercentage) / PERCENTAGE_SCALE;
            uint256 currentAllocationUsd = _convertToUsd(
                IERC20(allocation.aToken).balanceOf(address(this)),
                allocation.oracle
            );

            if (currentAllocationUsd < targetAllocationUsd) {
              uint256 amountToDepositUsd = targetAllocationUsd - currentAllocationUsd;
              uint256 amountToDeposit = _convertFromUsd(amountToDepositUsd, allocation.oracle);
              depositsToProcess.push(DepositData({
                    mysticPool: mysticPool,
                    allocation: allocation,
                    amountToDeposit: amountToDeposit
                }));
            } else if (currentAllocationUsd > targetAllocationUsd) {
              uint256 amountToWithdrawUsd = currentAllocationUsd - targetAllocationUsd;
              uint256 amountToWithdraw = _convertFromUsd(amountToWithdrawUsd, allocation.oracle);
              _withdrawFromMysticPool(mysticPool, allocation, amountToWithdraw);
            }
        }
    }

    // Process cached deposits
    for (uint256 k = 0; k < depositsToProcess.length; ) {
        DepositData memory depositData = depositsToProcess[k];
        _depositToMystic(depositData.mysticPool, depositData.allocation, depositData.amountToDeposit);

        unchecked {
            k++; 
        }
    }

    emit Rebalanced();
}

  function _depositToMystic(
    address mysticPool,
    AssetAllocation memory allocation,
    uint256 amount
  ) internal {
    IERC20(allocation.asset).safeApprove(mysticPool, amount);
    IPool(mysticPool).supply(allocation.asset, amount, address(this), 0);
  }

  function _withdrawFromMystic(uint256 assetsUsd) internal {
    for (uint256 i = 0; i < mysticPools.length; i++) {
      address mysticPool = mysticPools[i];
      for (uint256 j = 0; j < poolAssets[mysticPool].length; j++) {
        address asset = poolAssets[mysticPool][j];
        AssetAllocation memory allocation = assetAllocations[mysticPool][asset];
        uint256 aTokenBalance = IERC20(allocation.aToken).balanceOf(address(this));
        uint256 aTokenBalanceUsd = _convertToUsd(aTokenBalance, allocation.oracle);

        if (aTokenBalanceUsd > 0) {
          uint256 amountToWithdrawUsd = aTokenBalanceUsd < assetsUsd ? aTokenBalanceUsd : assetsUsd;
          uint256 amountToWithdraw = _convertFromUsd(amountToWithdrawUsd, allocation.oracle);
          IPool(mysticPool).withdraw(allocation.asset, amountToWithdraw, address(this));
          assetsUsd -= amountToWithdrawUsd;

          if (assetsUsd == 0) break;
        }
      }
      if (assetsUsd == 0) break;
    }
  }

  function _withdrawFromMysticPool(
    address mysticPool,
    AssetAllocation memory allocation,
    uint256 amount
  ) internal {
    IPool(mysticPool).withdraw(allocation.asset, amount, address(this));
  }

  function _updateLastValidPrice(address _oracle, uint _price) internal {
    uint price = _price;
    if(_price == 0){
      (, int256 price_, , , ) = AggregatorV3Interface(_oracle).latestRoundData();
      price = uint256(price_);
    }
    lastValidPrice[_oracle] = price;
  }

  function _priceThresholds(address _oracle) internal view returns (uint, uint) {
    
    uint256 price = lastValidPrice[_oracle];
    uint deviation = price * 2000/PERCENTAGE_SCALE;
    return (price - deviation, price + deviation);
  }

  function _convertToUsd(uint256 amount, address oracle) internal view returns (uint256) {
    (, int256 price, , uint256 updatedAt, ) = AggregatorV3Interface(oracle).latestRoundData();
    uint decimals = AggregatorV3Interface(oracle).decimals();
    (uint min, uint max) = _priceThresholds(oracle);

    require(price > 0, 'Invalid Price');
    require(decimals > 0, 'Invalid Decimals');
    require(updatedAt >= block.timestamp - priceFeedUpdateInterval, 'Out of Date');
    require(uint256(price) >= min && uint256(price) <= max, "Price not within threshold");
    _updateLastValidPrice(oracle, uint256(price));
    return (amount * uint256(price)) / 10 ** decimals; // Assuming 8 decimal places for price feed
  }

  function _convertFromUsd(uint256 amountUsd, address oracle) internal view returns (uint256) {
    // int256 price = AggregatorInterface(oracle).latestAnswer();
    (, int256 price, , uint256 updatedAt, ) = AggregatorV3Interface(oracle).latestRoundData();
    uint decimals = AggregatorV3Interface(oracle).decimals();

    require(price > 0, 'Invalid Price');
    require(decimals > 0, 'Invalid Decimals');
    require(updatedAt >= block.timestamp - priceFeedUpdateInterval, 'Out of Date');
    return (amountUsd * 10 ** decimals) / uint256(price); // Assuming 8 decimal places for price feed
  }

  function accrueFees(uint totalAssetValue) internal returns (uint256 remaining) {
    uint256 feeAmount = (totalAssetValue * fee) / PERCENTAGE_SCALE;
    uint256 feeShares = _convertToShares(feeAmount, Math.Rounding.Floor);
    _transfer(msg.sender, feeRecipient, feeShares);
    emit FeeAccrued(feeAmount);

    return totalAssetValue - feeAmount;
  }

  function accrueFees(uint shares, uint) internal returns (uint256 remaining) {
    //trigger function overload without extra params
    uint256 feeShares = (shares * fee) / PERCENTAGE_SCALE;
    uint256 feeAmount = _convertToAssets(feeShares, Math.Rounding.Floor);
    _transfer(msg.sender, feeRecipient, feeShares);
    emit FeeAccrued(feeAmount);

    return shares - feeShares;
  }

  function withdrawFees() external {
    require(msg.sender == feeRecipient, 'Only fee recipient can withdraw fees');
    uint256 feeShares = balanceOf(feeRecipient);
    uint256 feeAssets = _convertToAssets(feeShares, Math.Rounding.Floor);
    _burn(feeRecipient, feeShares);
    IERC20(asset()).safeTransfer(feeRecipient, feeAssets);
    emit FeesWithdrawn(feeAssets);
  }

  function simulateWithdrawal(uint256 assets) external view returns (uint256) {
    return _convertToShares(assets, Math.Rounding.Floor);
  }

  function simulateSupply(uint256 assets) external view returns (uint256) {
    return _convertToShares(assets, Math.Rounding.Floor);
  }

  function _isAssetAndPoolSupported(
    address asset,
    address mysticPool
  ) internal view returns (bool) {
    return assetAllocations[mysticPool][asset].asset != address(0);
  }

  function getMysticPools() external view returns (address[] memory) {
    return mysticPools;
  }

  function getPoolAssets(address mysticPool) external view returns (address[] memory) {
    return poolAssets[mysticPool];
  }

  function getTotalAllocation(address mysticPool) public view returns (uint256) {
    uint256 totalAllocation = 0;
    for (uint256 i = 0; i < poolAssets[mysticPool].length; i++) {
      address asset = poolAssets[mysticPool][i];
      totalAllocation += assetAllocations[mysticPool][asset].allocationPercentage;
    }
    return totalAllocation;
  }

  function getAPRs() public view returns (APRData memory) {
    require(mysticPools.length > 0, 'No Mystic pools added');

    uint256 totalSupplyAPR = 0;
    uint256 totalBorrowAPR = 0;
    uint256 totalWeight = 0;

    for (uint256 i = 0; i < mysticPools.length; i++) {
      address mysticPool = mysticPools[i];
      AssetAllocation memory allocation = assetAllocations[mysticPool][asset()];

      if (allocation.allocationPercentage > 0) {
        (uint256 supplyAPR, uint256 borrowAPR) = _getAssetAPRs(mysticPool);

        uint256 weight = allocation.allocationPercentage;
        totalSupplyAPR += supplyAPR * weight;
        totalBorrowAPR += borrowAPR * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight == 0) {
      return APRData(0, 0);
    }



    return APRData(totalSupplyAPR / totalWeight, totalBorrowAPR / PERCENTAGE_SCALE);
  }

  function _getAssetAPRs(
    address mysticPool
  ) internal view returns (uint256 supplyAPR, uint256 borrowAPR) {
    IPool pool = IPool(mysticPool);

    DataTypes.ReserveDataLegacy memory baseData = pool.getReserveData(asset());
    uint256 liquidityRate = baseData.currentLiquidityRate;
    uint256 variableBorrowRate = baseData.currentVariableBorrowRate;

    // Convert ray (1e27) to percentage with 2 decimals (1e4)
    supplyAPR = liquidityRate / 1e23;
    borrowAPR = variableBorrowRate / 1e23; // Using variable borrow rate
  }

  function _getAssetATokenAddress(address mysticPool) internal view returns (address) {
    IPool pool = IPool(mysticPool);

    DataTypes.ReserveDataLegacy memory baseData = pool.getReserveData(asset());
    return baseData.aTokenAddress;
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
