// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'src/core/contracts/dependencies/openzeppelin/contracts/ERC20.sol';

contract ERC20Mock is ERC20 {
  address public owner;

  constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
    owner = msg.sender;
    // _setupDecimals(decimals);
  }

  function mint(address to, uint256 amount) external {
    // require(msg.sender == owner, 'Only the owner can mint');
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) external {
    // require(msg.sender == owner, 'Only the owner can burn');
    _burn(from, amount);
  }

  // function _setupDecimals(uint8 decimals) internal {
  //   // This function is used to set the decimals for the token
  //   // OpenZeppelin's ERC20 does not have a public setter for decimals
  //   // So we override the decimals function to return the desired value
  //   // This is a workaround for testing purposes
  //   _decimals = decimals;
  // }

  // Override decimals function to return the custom decimals
  // uint8 private _decimals;

  // function decimals() public view virtual override returns (uint8) {
  //   return _decimals;
  // }
}
