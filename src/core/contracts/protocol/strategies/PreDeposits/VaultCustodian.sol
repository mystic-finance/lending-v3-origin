// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
// import '@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol';

// contract VaultCustodian {
//   using SafeERC20 for IERC20;

//   address public owner;
//   ILayerZeroEndpoint public layerZeroEndpoint;
//   uint16 public sourceChainId;
//   address public sourceVault;

//   IERC20 public asset;
//   address public pool;
//   IERC20 public poolLpToken;
//   IERC20 public incentiveToken;

//   mapping(address => uint256) public userLpBalances;
//   mapping(address => uint256) public userIncentives;

//   event Deposited(address indexed user, uint256 amount);
//   event Withdrawn(address indexed user, uint256 amount);
//   event RewardsClaimed(address indexed user, uint256 amount);

//   modifier onlyOwner() {
//     require(msg.sender == owner, 'Not owner');
//     _;
//   }

//   constructor(
//     ILayerZeroEndpoint _layerZeroEndpoint,
//     uint16 _sourceChainId,
//     address _sourceVault,
//     IERC20 _asset,
//     address _pool,
//     IERC20 _poolLpToken,
//     IERC20 _incentiveToken
//   ) {
//     owner = msg.sender;
//     layerZeroEndpoint = _layerZeroEndpoint;
//     sourceChainId = _sourceChainId;
//     sourceVault = _sourceVault;
//     asset = _asset;
//     pool = _pool;
//     poolLpToken = _poolLpToken;
//     incentiveToken = _incentiveToken;
//   }

//   // Update emission rate (only owner)
//   function updateEmissionRate(uint256 newEmissionRate) external onlyOwner {
//     emissionRate = newEmissionRate;
//     emit EmissionRateUpdated(newEmissionRate);
//   }

//   // Handle incoming messages from Chain 1
//   function lzReceive(
//     uint16 _srcChainId,
//     bytes memory _srcAddress,
//     uint64 _nonce,
//     bytes memory _payload
//   ) external {
//     require(msg.sender == address(layerZeroEndpoint), 'Invalid endpoint');
//     require(_srcChainId == sourceChainId, 'Invalid source chain');

//     (uint256 amount, address user) = abi.decode(_payload, (uint256, address));

//     if (user == sourceVault) {
//       // Deposit into the pool
//       asset.safeApprove(pool, amount);
//       (bool success, ) = pool.call(
//         abi.encodeWithSignature(
//           'deposit(address,uint256,address)',
//           address(asset),
//           amount,
//           address(this)
//         )
//       );
//       require(success, 'Deposit failed');

//       // Distribute LP tokens to the vault custodian
//       uint256 lpTokens = poolLpToken.balanceOf(address(this));
//       userLpBalances[user] += lpTokens;

//       emit Deposited(user, amount);
//     } else {
//       // Withdraw assets and bridge back to Chain 1
//       uint256 incentives = _calculateIncentives(user);
//       userIncentives[user] += incentives;

//       // Transfer assets and incentives to the vault
//       asset.safeTransfer(sourceVault, amount);
//       incentiveToken.safeTransfer(sourceVault, incentives);

//       emit Withdrawn(user, amount);
//     }
//   }

//   // Calculate incentives for a user
//   function _calculateIncentives(address user) internal view returns (uint256) {
//     uint256 timeElapsed = block.timestamp - lastUpdateTime;
//     return (userLpBalances[user] * emissionRate * timeElapsed) / 1e18;
//   }

//   // Claim LP tokens and incentives
//   function claimLpAndIncentives(uint256 lpAmount) external nonReentrant {
//     require(userLpBalances[msg.sender] >= lpAmount, 'Insufficient LP balance');

//     // Transfer LP tokens to the user
//     poolLpToken.safeTransfer(msg.sender, lpAmount);
//     userLpBalances[msg.sender] -= lpAmount;

//     // Transfer incentives to the user
//     uint256 incentives = userIncentives[msg.sender];
//     if (incentives > 0) {
//       userIncentives[msg.sender] = 0;
//       incentiveToken.safeTransfer(msg.sender, incentives);
//     }

//     emit RewardsClaimed(msg.sender, incentives);
//   }
// }
