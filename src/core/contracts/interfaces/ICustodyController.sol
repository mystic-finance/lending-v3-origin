// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title ICustodyController
 * @dev Interface for the CustodyController contract managing asset custody and withdrawals
 */
interface ICustodyController {
  // Enum for Withdrawal Request Status
  enum RequestStatus {
    Pending,
    CustodianWithdrawalApproved,
    CustodianWithdrawalRejected
  }

  // Struct for Asset Information
  struct AssetInfo {
    address tokenAddress;
    uint256 totalDeposited;
    bool isActive;
  }

  // View Functions
  function custodyWallet() external view returns (address);
  function repoLocker() external view returns (address);
  function lastRequestId() external view returns (bytes32);
  function pendingWithdrawals(address asset) external view returns (uint256);
  function supportedAssets(address asset) external view returns (AssetInfo memory);
  function assetWithdrawalLimits(address asset) external view returns (uint256);
  function approvedTargets(address target) external view returns (bool);

  // Role-based Constants
  function TREASURY_MANAGER_ROLE() external view returns (bytes32);
  function WITHDRAWAL_OPERATOR_ROLE() external view returns (bytes32);
  function CUSTODIAN_OPERATOR_ROLE() external view returns (bytes32);

  /**
   * @dev Deposit assets into the treasury
   * @param token Address of the token to deposit
   * @param amount Amount of tokens to deposit
   */
  function depositAsset(address token, uint256 amount) external;

  /**
   * @dev Request withdrawal with custodian integration
   * @param assets Array of token addresses
   * @param amounts Array of withdrawal amounts
   * @param target Target contract/address for potential callback
   * @param data Callback data
   * @return requestId Unique request identifier
   */
  function requestWithdrawal(
    address[] memory assets,
    uint256[] memory amounts,
    address target,
    bytes memory data
  ) external returns (bytes32);

  /**
   * @dev Update request status after Anchorage API interaction
   * @param requestId Unique request identifier
   * @param newStatus New status for the request
   */
  function updateRequest(bytes32 requestId, RequestStatus newStatus) external;

  /**
   * @dev Add a new supported asset
   * @param token Token address to support
   */
  function addSupportedAsset(address token) external;

  /**
   * @dev Add a new supported target
   * @param _target target to support
   */
  function addApprovedTarget(address _target) external;

  /**
   * @dev Update custody wallet address
   * @param newCustodyWallet New custody wallet address
   */
  function updateCustodyWallet(address newCustodyWallet) external;

  /**
   * @dev Update repo locker address
   * @param _repoLocker New repo locker address
   */
  function updateLocker(address _repoLocker) external;

  /**
   * @dev Set withdrawal limit for a specific asset
   * @param asset Token address
   * @param limit Maximum withdrawal amount
   */
  function setWithdrawalLimit(address asset, uint256 limit) external;

  /**
   * @dev Check if an asset is supported for custody
   * @param token Address of the token to check
   * @return Boolean indicating if the asset is supported
   */
  function isSupportedAsset(address token) external view returns (bool);

  /**
   * @dev Batch grant withdrawal operator roles
   * @param _newWithdrawalOperators Array of addresses to grant withdrawal operator role
   */
  function batchGrantWithdrawalOperatorRole(address[] calldata _newWithdrawalOperators) external;

  /**
   * @dev Remove withdrawal operator role
   * @param _withdrawalOperator Address to revoke withdrawal operator role
   */
  function revokeWithdrawalOperatorRole(address _withdrawalOperator) external;

  /**
   * @dev Get supported asset details
   * @param token Address of the token
   * @return tokenAddress Token address
   * @return totalDeposited Total amount deposited
   * @return isActive Whether the asset is active
   */
  function getSupportedAssetDetails(
    address token
  ) external view returns (address tokenAddress, uint256 totalDeposited, bool isActive);

  /**
   * @dev Pause contract operations
   */
  function pause() external;

  /**
   * @dev Unpause contract operations
   */
  function unpause() external;

  // Events
  event AssetDeposited(address indexed token, uint256 amount, address indexed depositor);
  event WithdrawalRequestCreated(
    bytes32 indexed requestId,
    address indexed user,
    address indexed asset,
    address target,
    uint256 amount
  );
  event RequestStatusUpdated(bytes32 indexed requestId, RequestStatus newStatus);
  event WithdrawalCompleted(
    bytes32 indexed requestId,
    address indexed user,
    address indexed asset,
    uint256 amount
  );
  event CustodyWalletUpdated(address newCustodyWallet);
  event RepoLockerUpdated(address newCustodyWallet);
}
