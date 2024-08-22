// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import '../../dependencies/openzeppelin/contracts/Ownable.sol';
import '../../interfaces/IPool.sol';

interface IPointsProgram {
  function incrementTaskPoints(address user, uint8 task) external;
}

contract AavePoolWrapper is Ownable {
  using SafeERC20 for IERC20;

  IPointsProgram public pointsProgram;
  uint8 public task;

  constructor(address _pointsProgram, uint8 _task) {
    pointsProgram = IPointsProgram(_pointsProgram);
    task = _task;
  }

  function updateTask(uint8 _task) external onlyOwner {
    task = _task;
  }

  function updatePointProgram(address _pointsProgram) external onlyOwner {
    pointsProgram = IPointsProgram(_pointsProgram);
  }

  function supply(address _aavePool, address asset, uint256 amount) external {
    IPool aavePool = IPool(_aavePool);
    // Transfer tokens from user to this contract
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

    // Approve Aave pool to spend tokens
    IERC20(asset).safeApprove(address(aavePool), amount);

    // Supply to Aave pool
    aavePool.supply(asset, amount, msg.sender, 0);

    // Add points for the user
    pointsProgram.incrementTaskPoints(msg.sender, task);
  }
}
