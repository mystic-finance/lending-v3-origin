// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolAddressesProvider} from '../../../interfaces/IPoolAddressesProvider.sol';
import {IPool} from '../../../interfaces/IPool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

interface IFlashLoanController {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external;
}

contract AaveV3Flashloaner is ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Aave Pool Addresses Provider
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  // Aave Pool
  IPool public immutable POOL;

  // Flashloan fee
  uint256 public constant FLASHLOAN_FEE_TOTAL = 0.09 * 10000; // 0.09%
  uint256 public constant FLASHLOAN_FEE_PROTOCOL = 0.02 * 10000; // 0.02%

  // Events
  event FlashLoanInitiated(address indexed asset, uint256 amount, uint256 premium);
  event FlashLoanRepaid(address indexed asset, uint256 amount, uint256 premium);

  constructor(address _addressProvider) {
    ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
    POOL = IPool(ADDRESSES_PROVIDER.getPool());
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

    uint256[] memory interestRateModes = new uint256[](1);
    interestRateModes[0] = 0; // 0 = no debt, 1 = stable, 2 = variable

    POOL.flashLoan(address(this), assets, amounts, interestRateModes, address(this), params, 0);
  }

  /**
   * @dev Aave V3 Flashloan callback function
   * IMPORTANT: This MUST be implemented by the inheriting contract
   */
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    // Validate caller is the Aave Pool
    require(msg.sender == address(POOL), 'Unauthorized caller');

    // Perform your custom logic here
    _processFlashloan(assets, amounts, premiums, initiator, params);

    // Approve the Pool to spend the owed amount + premium
    uint256 amountOwed = amounts[0] + premiums[0];
    IERC20(assets[0]).approve(address(POOL), amountOwed);

    emit FlashLoanRepaid(assets[0], amounts[0], premiums[0]);

    return true;
  }

  /**
   * @dev Internal method to process the flashloan
   * Must be overridden by inheriting contract
   */
  function _processFlashloan(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes memory params
  ) internal {
    // TODO: add processing data
    // Decode and validate params
    (, , address borrowToken, , , address flashLoanController, ) = abi.decode(
      params,
      (address, address, address, uint256, uint256, address, address)
    );

    IERC20(borrowToken).transfer(flashLoanController, amounts[0]);

    IFlashLoanController(flashLoanController).executeOperation(
      assets,
      amounts,
      premiums,
      initiator,
      params
    );

    uint256 amountOwed = amounts[0] + premiums[0];
    IERC20(borrowToken).transferFrom(flashLoanController, address(this), amountOwed);
  }

  /**
   * @dev Calculate flashloan fee
   * @param asset Address of the token
   * @param amount Flashloan amount
   * @return Fee for the flashloan
   */
  function getFlashLoanFee(address asset, uint256 amount) external pure returns (uint256) {
    return (amount * FLASHLOAN_FEE_TOTAL) / 10000;
  }

  /**
   * @dev Rescue tokens accidentally sent to the contract
   */
  function rescueTokens(address tokenAddress, uint256 amount) external {
    IERC20(tokenAddress).safeTransfer(msg.sender, amount);
  }
}
