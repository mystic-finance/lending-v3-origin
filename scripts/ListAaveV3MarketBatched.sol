// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ListAaveV3MarketBatchedBase} from './misc/ListAaveV3MarketBatchedBase.sol';

import {DefaultMarketInput} from '../src/deployments/inputs/DefaultMarketInput.sol';

contract Default is ListAaveV3MarketBatchedBase, DefaultMarketInput {}
