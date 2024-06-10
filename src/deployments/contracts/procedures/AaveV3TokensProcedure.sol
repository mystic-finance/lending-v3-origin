// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ATokenInstance} from 'src/core/instances/ATokenInstance.sol';
import {VariableDebtTokenInstance} from 'src/core/instances/VariableDebtTokenInstance.sol';
import {StableDebtTokenInstance} from 'src/core/instances/StableDebtTokenInstance.sol';
import {IPool} from 'src/core/contracts/interfaces/IPool.sol';
import {IAaveIncentivesController} from 'src/core/contracts/interfaces/IAaveIncentivesController.sol';

contract AaveV3TokensProcedure {
  struct TokensReport {
    address aToken;
    address variableDebtToken;
    address stableDebtToken;
  }

  function _deployAaveV3TokensImplementations(
    address poolProxy,
    address treasury,
    address underlyingAsset,
    address debtAsset
  ) internal returns (TokensReport memory) {
    TokensReport memory tokensReport;
    bytes memory empty;

    ATokenInstance aToken = new ATokenInstance(IPool(poolProxy));
    VariableDebtTokenInstance variableDebtToken = new VariableDebtTokenInstance(IPool(poolProxy));
    StableDebtTokenInstance stableDebtToken = new StableDebtTokenInstance(IPool(poolProxy));

    aToken.initialize(
      IPool(poolProxy), // pool proxy
      treasury, // treasury
      underlyingAsset, // asset
      IAaveIncentivesController(address(0)), // incentives controller
      18, // decimals
      'ATOKEN_IMPL', // name
      'ATOKEN_IMPL', // symbol
      empty // params
    );

    variableDebtToken.initialize(
      IPool(poolProxy), // initializingPool
      debtAsset, // underlyingAsset
      IAaveIncentivesController(address(0)), // incentivesController
      18, // debtTokenDecimals
      'VARIABLE_DEBT_TOKEN_IMPL', // debtTokenName
      'VARIABLE_DEBT_TOKEN_IMPL', // debtTokenSymbol
      empty // params
    );

    stableDebtToken.initialize(
      IPool(poolProxy), // initializingPool
      debtAsset, // underlyingAsset
      IAaveIncentivesController(address(0)), // incentivesController
      18, // debtTokenDecimals
      'STABLE_DEBT_TOKEN_IMPL', // debtTokenName
      'STABLE_DEBT_TOKEN_IMPL', // debtTokenSymbol
      empty // params
    );

    tokensReport.aToken = address(aToken);
    tokensReport.variableDebtToken = address(variableDebtToken);
    tokensReport.stableDebtToken = address(stableDebtToken);

    return tokensReport;
  }
}
