// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

interface IStrategy {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external;
}

interface IFlashLoanProvider {
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) external;

  function getMaxFlashLoanAmount(address asset) external view returns (uint256);
  function getFlashLoanFee(address asset, uint256 amount) external view returns (uint256);
}

contract FlashLoanController is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Current active flash loan provider
  IFlashLoanProvider public currentProvider;

  // Events to track provider and flash loan operations
  event ProviderUpdated(address indexed newProvider, address indexed oldProvider);
  event FlashLoanInitiated(address indexed asset, uint256 amount, address indexed provider);
  event FlashLoanProcessed(address indexed asset, uint256 amount, uint256 fee);

  constructor(address _initialProvider) Ownable(msg.sender) {
    require(_initialProvider != address(0), 'Invalid provider address');
    currentProvider = IFlashLoanProvider(_initialProvider);
  }

  /**
   * @dev Update the flash loan provider contract
   * @param _newProvider Address of the new flash loan provider
   */
  function updateProvider(address _newProvider) external onlyOwner {
    require(_newProvider != address(0), 'Invalid provider address');

    address oldProvider = address(currentProvider);
    currentProvider = IFlashLoanProvider(_newProvider);

    emit ProviderUpdated(_newProvider, oldProvider);
  }

  /**
   * @dev Initiate a flash loan using the current provider
   * @param asset Address of the token to flash loan
   * @param amount Amount of tokens to flash loan
   * @param params Additional parameters for the flash loan operation
   */
  function executeFlashLoan(
    address asset,
    uint256 amount,
    bytes memory params
  ) external nonReentrant {
    require(asset != address(0), 'Invalid asset address');
    require(amount > 0, 'Amount must be greater than 0');

    emit FlashLoanInitiated(asset, amount, address(currentProvider));

    // Delegate flash loan execution to current provider
    currentProvider.executeFlashLoan(asset, amount, params);
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    // Verify caller is the flash loan controller
    require(msg.sender == address(currentProvider), 'Unauthorized flash loan');
    // Decode and validate params
    (, , , address borrowToken, , , , address strategy, ) = abi.decode(
      params,
      (uint256, address, address, address, uint256, uint256, address, address, uint8)
    );

    IERC20(borrowToken).transfer(strategy, amounts[0]);

    IStrategy(strategy).executeOperation(assets, amounts, premiums, initiator, params);

    uint256 amountOwed = amounts[0] + premiums[0];
    IERC20(borrowToken).transferFrom(strategy, address(this), amountOwed);
    IERC20(borrowToken).approve(address(currentProvider), amountOwed);

    return true;
  }

  /**
   * @dev Get maximum flash loan amount for a specific asset
   * @param asset Address of the token
   * @return Maximum flash loan amount
   */
  function getMaxFlashLoanAmount(address asset) external view returns (uint256) {
    return currentProvider.getMaxFlashLoanAmount(asset);
  }

  /**
   * @dev Calculate flash loan fee
   * @param asset Address of the token
   * @param amount Flash loan amount
   * @return Fee for the flash loan
   */
  function getFlashLoanFee(address asset, uint256 amount) external view returns (uint256) {
    return currentProvider.getFlashLoanFee(asset, amount);
  }

  /**
   * @dev Rescue tokens accidentally sent to the contract
   * @param tokenAddress Address of the token to rescue
   * @param amount Amount of tokens to rescue
   */
  function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
    IERC20(tokenAddress).safeTransfer(owner(), amount);
  }
}
