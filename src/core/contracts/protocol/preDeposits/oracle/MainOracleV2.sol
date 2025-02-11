// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {Oracle} from './Oracle.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import '../Errors.sol';

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

contract MainOracleV2 is Oracle, AccessControl {
  uint256 public constant D18 = 1e18;
  bytes32 public constant ORACLE_OPERATOR_ROLE = keccak256('ORACLE_OPERATOR_ROLE');

  uint256[] internal prices;
  AggregatorV3Interface public immutable aggregator;

  constructor(address _token, string memory _name, address _aggregator) Oracle(_token, _name) {
    require(_token != address(0), "ZERO ADDRESS");
    require(_aggregator != address(0), "ZERO ADDRESS");

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    aggregator = AggregatorV3Interface(_aggregator);
  }

  function getPrice() external view override returns (uint256 price) {
    (
      ,
      int256 _price,
      ,
      ,
      
    ) = aggregator.latestRoundData();

    uint decimals = aggregator.decimals();

    if (decimals > 18) {
        _price = _price / int256(10 ** (decimals - 18));
    } else if (decimals < 18) {
        _price = _price * int256(10 ** (18 - decimals));
    }
    price = uint256(_price);
  }

  function _updatePrice(uint _price) internal {
    if (_price == 0) revert InvalidPrice();

    revert();
  }

  function updatePrice(uint _price) public onlyRole(ORACLE_OPERATOR_ROLE) {
    _updatePrice(_price);
  }
}
