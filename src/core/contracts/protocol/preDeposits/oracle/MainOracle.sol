// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {Oracle} from './Oracle.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import '../Errors.sol';

contract MainOracle is Oracle, AccessControl {
  uint256 public constant D18 = 1e18;
  bytes32 public constant ORACLE_OPERATOR_ROLE = keccak256('ORACLE_OPERATOR_ROLE');

  uint256[] internal prices;

  constructor(address _token, string memory _name, uint256 _initPrice) Oracle(_token, _name) {
    require(_token != address(0), 'ZERO ADDRESS');
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);


    _updatePrice(_initPrice);
  }

  function getPrice() external view override returns (uint256 price) {
    price = prices[prices.length - 1];
  }

  function _updatePrice(uint _price) internal {
    if (_price == 0) revert InvalidPrice();

    prices.push(_price);
  }

  function updatePrice(uint _price) public onlyRole(ORACLE_OPERATOR_ROLE) {
    _updatePrice(_price);
  }
}
