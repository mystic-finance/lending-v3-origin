// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeployAaveBundlerBased} from './misc/DeployAaveBundlerBased.sol';

import {DefaultMarketInput} from '../src/deployments/inputs/DefaultMarketInput.sol';

contract Default is DeployAaveBundlerBased, DefaultMarketInput {}
