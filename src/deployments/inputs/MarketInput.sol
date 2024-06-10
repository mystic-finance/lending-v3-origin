// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '../interfaces/IMarketReportTypes.sol';
import 'src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';

abstract contract MarketInput {
  function _getMarketInput(
    address
  )
    internal
    view
    virtual
    returns (
      Roles memory roles,
      MarketConfig memory config,
      SubMarketConfig memory subConfig,
      DeployFlags memory flags,
      MarketReport memory deployedContracts
    );

  function _listAsset(address) internal view virtual returns (ListingConfig memory config);

  function _updateCollateral(address) internal view virtual returns (ListingConfig memory config);

  function _updateBorrowAsset(address) internal view virtual returns (ListingConfig memory config);
}
