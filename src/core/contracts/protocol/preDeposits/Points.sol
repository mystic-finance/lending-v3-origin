// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// @title Points
/// @author CopyPaste, Jack Corddry, Shivaansh Kapoor
/// @dev A simple contract for running Points Programs
contract Points {
  event Award(address indexed to, uint256 indexed amount, address indexed awardedBy);
  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor() {}

  /*//////////////////////////////////////////////////////////////
                                 POINTS
    //////////////////////////////////////////////////////////////*/

  /// @param to The address to mint points to
  /// @param amount  The amount of points to award to the `to` address
  function award(address to, uint256 amount) external {
    emit Award(to, amount, msg.sender);
  }

  /// @param to The address to mint points to
  /// @param amount  The amount of points to award to the `to` address
  /// @param ip The incentive provider attempting to mint the points
  function award(address to, uint256 amount, address ip) external {
    emit Award(to, amount, ip);
  }
}
