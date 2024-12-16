// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

interface IBalancerVault {
  function flashLoan(
    address receiver,
    address[] calldata assets,
    uint256[] calldata amounts,
    bytes memory params
  ) external;
}

interface IFlashLoanController {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external;
}

contract BalancerFlashloaner is ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Balancer Vault
  IBalancerVault public immutable BALANCER_VAULT;

  // Events
  event FlashLoanInitiated(address indexed asset, uint256 amount);
  event FlashLoanRepaid(address indexed asset, uint256 amount);

  constructor(address _balancerVault) {
    BALANCER_VAULT = IBalancerVault(_balancerVault);
  }

  /**
   * @dev Initiate a Flashloan
   * @param asset Address of the token to flashloan
   * @param amount Amount of tokens to flashloan
   * @param params Additional parameters for the flashloan operation
   */
  function executeFlashLoan(address asset, uint256 amount, bytes memory params) public {
    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amount;

    emit FlashLoanInitiated(asset, amount);

    BALANCER_VAULT.flashLoan(address(this), assets, amounts, params);
  }

  /**
   * @dev Balancer Flashloan callback function
   */
  function receiveFlashLoan(
    address[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    bytes memory params
  ) external nonReentrant {
    // Validate caller is the Balancer Vault
    require(msg.sender == address(BALANCER_VAULT), 'Unauthorized caller');

    // Perform your custom logic here
    _processFlashloan(tokens, amounts, feeAmounts, msg.sender, params);

    // Prepare repayment (amount + fee)
    uint256 amountOwed = amounts[0] + feeAmounts[0];
    IERC20(tokens[0]).approve(address(BALANCER_VAULT), amountOwed);

    emit FlashLoanRepaid(address(tokens[0]), amounts[0]);
  }

  /**
   * @dev Internal method to process the flashloan
   * Must be overridden by inheriting contract
   */
  function _processFlashloan(
    address[] memory assets,
    uint256[] memory amounts,
    uint256[] memory premiums,
    address initiator,
    bytes memory params
  ) internal {
    // Decode and validate params
    (
      address user,
      address collateralToken,
      address borrowToken,
      uint256 initialCollateral,
      uint256 leverageMultiplier,
      address flashLoanController,
      address strategy
    ) = abi.decode(params, (address, address, address, uint256, uint256, address, address));

    IFlashLoanController(flashLoanController).executeOperation(
      assets,
      amounts,
      premiums,
      initiator,
      params
    );

    uint256 amountOwed = amounts[0] + premiums[0];
    IERC20(borrowToken).transferFrom(msg.sender, address(this), amountOwed);
  }

  /**
   * @dev Rescue tokens accidentally sent to the contract
   */
  function rescueTokens(address tokenAddress, uint256 amount) external {
    IERC20(tokenAddress).safeTransfer(msg.sender, amount);
  }
}
