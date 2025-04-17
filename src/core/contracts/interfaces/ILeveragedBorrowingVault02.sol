// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILeveragedBorrowingVault02 {
  // --- Struct Definitions ---
  struct UserPosition {
    address user;
    address collateralToken;
    address borrowToken;
    uint256 initialCollateral;
    uint256 totalCollateral;
    uint256 totalBorrowed;
    uint256 leverageMultiplier;
    bool isActive;
  }

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

  // --- Core Position Functions ---
  /// @notice Opens or updates a leveraged position.
  /// If a position with the same (user, collateral, borrow) exists it will update it.
  /// @param collateralToken The address of the collateral token.
  /// @param borrowToken The address of the token to borrow.
  /// @param initialCollateral The amount of collateral to deposit.
  /// @param leverageMultiplier The leverage multiplier (> 1 and <= MAX_LEVERAGE).
  function openLeveragePosition(
    address collateralToken,
    address borrowToken,
    uint256 initialCollateral,
    uint256 leverageMultiplier
  ) external;

  /// @notice Closes an active leveraged position.
  /// @param collateralToken The collateral token address of the position.
  /// @param borrowToken The borrow token address of the position.
  function closeLeveragePosition(address collateralToken, address borrowToken) external;

  /// @notice Updates a leveraged position.
  /// @param collateralToken The collateral token address of the position.
  /// @param borrowToken The borrow token address of the position.
  /// @param newInitialCollateral The new initial collateral amount.
  /// @param newLeverageMultiplier The new leverage multiplier.
  function updateLeveragePosition(
    address collateralToken,
    address borrowToken,
    uint256 newInitialCollateral,
    uint256 newLeverageMultiplier
  ) external;

  // --- Flash Loan Receiver Interface ---
  /// @notice Called by the flash loan controller during flash loan operations.
  /// @param assets The asset addresses involved in the flash loan.
  /// @param amounts The amounts for each asset.
  /// @param premiums The premium amounts for each asset.
  /// @param initiator The address initiating the flash loan.
  /// @param params Additional encoded parameters.
  /// @return A boolean indicating success.
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);

  // --- Getter Functions ---
  /// @notice Returns an array of position IDs for a given user.
  /// @param user The address of the user.
  function getUserPositions(address user) external view returns (uint256[] memory);

  /// @notice Returns an array of active position IDs for a given user.
  /// @param user The address of the user.
  function getUserActivePositionIds(address user) external view returns (uint256[] memory);

  // --- Getter Functions for Mappings ---
  /// @notice Returns a position by its ID.
  /// @param positionId The unique position identifier.
  /// @return user The position owner.
  /// @return collateralToken The collateral token address.
  /// @return borrowToken The borrowed token address.
  /// @return initialCollateral The initial collateral amount.
  /// @return totalCollateral The total collateral in the position.
  /// @return totalBorrowed The total amount borrowed.
  /// @return leverageMultiplier The leverage multiplier.
  /// @return isActive A flag indicating if the position is active.
  function positions(
    uint256 positionId
  )
    external
    view
    returns (
      address user,
      address collateralToken,
      address borrowToken,
      uint256 initialCollateral,
      uint256 totalCollateral,
      uint256 totalBorrowed,
      uint256 leverageMultiplier,
      bool isActive
    );

  /// @notice Returns the mapping key to position ID for a composite key.
  /// @param key The ABI‑encoded key (from encodeAddresses).
  /// @return The position ID stored for the key.
  function mapPositions(bytes calldata key) external view returns (uint256);

  function totalCollateral() external view returns (uint256);
  function totalBorrowed() external view returns (uint256);

  /// @notice Returns an array of position IDs for a given user.
  /// @param user The address of the user.
  /// @return An array of position IDs.
  function userPositions(address user) external view returns (uint256[] memory);

  /// @notice Checks if a given token is allowed as collateral.
  /// @param token The token address.
  /// @return A boolean indicating whether the token is allowed.
  function allowedCollateralTokens(address token) external view returns (bool);

  /// @notice Checks if a given token is allowed as borrowable.
  /// @param token The token address.
  /// @return A boolean indicating whether the token is allowed.
  function allowedBorrowTokens(address token) external view returns (bool);

  /// @notice Encodes the addresses used as a unique key (user, collateral, borrow).
  /// @param user The address of the user.
  /// @param collateral The address of the collateral token.
  /// @param borrow The address of the borrow token.
  /// @return The ABI encoded key.
  function encodeAddresses(
    address user,
    address collateral,
    address borrow
  ) external pure returns (bytes memory);

  // --- Admin Functions ---
  /// @notice Adds a collateral token to the list of allowed tokens.
  /// @param token The address of the token.
  function addAllowedCollateralToken(address token) external;

  /// @notice Adds a borrow token to the list of allowed tokens.
  /// @param token The address of the token.
  function addAllowedBorrowToken(address token) external;

  /// @notice Removes a collateral token from the allowed list.
  /// @param token The address of the token.
  function removeAllowedCollateralToken(address token) external;

  /// @notice Removes a borrow token from the allowed list.
  /// @param token The address of the token.
  function removeAllowedBorrowToken(address token) external;

  /// @notice Updates the swap fee.
  /// @param _swapFee The new swap fee value.
  function updateSwapFee(uint24 _swapFee) external;

  /// @notice Updates the address of the swap controller.
  /// @param _newSwapController The new swap controller address.
  function updateSwapController(address _newSwapController) external;

  /// @notice Updates the address of the flash loan controller.
  /// @param _newFlashLoanController The new flash loan controller address.
  function updateFlashLoanController(address _newFlashLoanController) external;
}
