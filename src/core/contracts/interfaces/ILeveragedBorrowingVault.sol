// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILeveragedBorrowingVault {
  // --- Events ---
  event LeveragePositionOpened(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 initialAmount,
    uint256 leverageMultiplier
  );
  event LeveragePositionClosed(
    uint256 indexed positionId,
    address indexed user,
    uint256 collateralReturned
  );
  event LeveragePositionAdded(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 addedCollateral,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );
  event LeveragePositionRemoved(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 removedCollateral,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );
  event LeveragePositionLeverageUpdated(
    uint256 indexed positionId,
    address indexed user,
    address collateralToken,
    address borrowToken,
    uint256 oldLeverageMultiplier,
    uint256 newLeverageMultiplier,
    uint256 newTotalCollateral,
    uint256 newTotalBorrowed
  );

  // --- Core Vault Functions ---
  /// @notice Opens a new leveraged position.
  /// @param collateralToken The address of the collateral token.
  /// @param borrowToken The address of the token to borrow.
  /// @param initialCollateral The amount of collateral deposited.
  /// @param leverageMultiplier The leverage multiplier.
  function openLeveragePosition(
    address collateralToken,
    address borrowToken,
    uint256 initialCollateral,
    uint256 leverageMultiplier
  ) external;

  /// @notice Closes an existing leveraged position.
  /// @param positionId The unique identifier of the position.
  function closeLeveragePosition(uint256 positionId) external;

  /// @notice Updates a leveraged position by modifying collateral and/or leverage.
  /// @param positionId The unique identifier of the position.
  /// @param newInitialCollateral The new collateral amount.
  /// @param newLeverageMultiplier The new leverage multiplier.
  function updateLeveragePosition(
    uint256 positionId,
    uint256 newInitialCollateral,
    uint256 newLeverageMultiplier
  ) external;

  /// @notice Returns all positions (by their IDs) for a given user.
  /// @param user The address of the user.
  /// @return An array of position IDs.
  function getUserPositions(address user) external view returns (uint256[] memory);

  /// @notice Returns active position IDs for a given user.
  /// @param user The address of the user.
  /// @return An array of active position IDs.
  function getUserActivePositionIds(address user) external view returns (uint256[] memory);

  // --- Flash Loan Receiver Interface Function ---
  /// @notice Executes a flash loan operation.
  /// @param assets The array of asset addresses involved.
  /// @param amounts The array of amounts for each asset.
  /// @param premiums The array of premiums for each asset.
  /// @param initiator The address that initiated the flash loan.
  /// @param params Additional encoded parameters for the operation.
  /// @return A boolean indicating whether the operation succeeded.
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);

  // --- Admin Functions ---
  /// @notice Adds a token to the list of allowed collateral tokens.
  /// @param token The address of the token.
  function addAllowedCollateralToken(address token) external;

  /// @notice Adds a token to the list of allowed borrow tokens.
  /// @param token The address of the token.
  function addAllowedBorrowToken(address token) external;

  /// @notice Removes a token from the allowed collateral tokens list.
  /// @param token The address of the token.
  function removeAllowedCollateralToken(address token) external;

  /// @notice Removes a token from the allowed borrow tokens list.
  /// @param token The address of the token.
  function removeAllowedBorrowToken(address token) external;

  /// @notice Updates the pool fee used for swaps.
  /// @param _swapFee The new swap fee.
  function updateSwapFee(uint24 _swapFee) external;

  /// @notice Updates the address of the swap controller.
  /// @param _newSwapController The address of the new swap controller.
  function updateSwapController(address _newSwapController) external;

  /// @notice Updates the address of the flash loan controller.
  /// @param _newFlashLoanController The address of the new flash loan controller.
  function updateFlashLoanController(address _newFlashLoanController) external;
}
