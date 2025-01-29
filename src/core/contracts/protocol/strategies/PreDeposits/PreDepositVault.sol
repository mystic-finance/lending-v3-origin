// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import '../../dependencies/openzeppelin/contracts/ERC4626.sol';
// import '../../dependencies/openzeppelin/contracts/Math.sol';
// import '../../dependencies/openzeppelin/contracts/IERC20.sol';
// import '../../dependencies/openzeppelin/contracts/Ownable.sol';
// import '@layerzerolabs/solidity-examples/contracts/lzApp/interfaces/ILayerZeroEndpoint.sol';
// import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

// contract PreDepositVault is ERC4626, ReentrancyGuard {
//   using SafeERC20 for IERC20;

//   uint256 public immutable lockupPeriod;
//   uint256 public launchTime;
//   address public owner;

//   // LayerZero and cross-chain parameters
//   ILayerZeroEndpoint public layerZeroEndpoint;
//   uint16 public targetChainId;
//   address public targetLendingPool;
//   uint16 public dstChainId;
//   address public vaultCustodian;
//   uint8 public immutable srcPoolId;
//   uint8 public immutable dstPoolId;

//   // Incentive parameters
//   IERC20 public rewardToken;
//   uint256 public rewardRate; // Rewards per second per share
//   uint256 public lastUpdateTime;
//   uint256 public rewardPerTokenStored;
//   mapping(address => uint256) public userRewardPerTokenPaid;
//   mapping(address => uint256) public rewards;
//   mapping(bytes32 => bool) public completedMessages;
//   mapping(address => uint256) public depositTimestamps;

//   // Events
//   event Deposited(address indexed user, uint256 amount);
//   event Bridged(uint256 amount, uint16 targetChainId, address targetLendingPool);
//   event Exchanged(address indexed user, uint256 vaultShares, uint256 poolShares);
//   event Withdrawn(address indexed user, uint256 amount);
//   event RewardsClaimed(address indexed user, uint256 amount);

//   modifier onlyOwner() {
//     require(msg.sender == owner, 'Not owner');
//     _;
//   }

//   modifier updateReward(address account) {
//     rewardPerTokenStored = rewardPerToken();
//     lastUpdateTime = block.timestamp;
//     if (account != address(0)) {
//       rewards[account] = earned(account);
//       userRewardPerTokenPaid[account] = rewardPerTokenStored;
//     }
//     _;
//   }

//   constructor(
//     IERC20 asset,
//     string memory name,
//     string memory symbol,
//     uint256 _lockupPeriod,
//     ILayerZeroEndpoint _layerZeroEndpoint,
//     uint16 _dstChainId,
//     address _vaultCustodian,
//     uint8 _srcPoolId,
//     uint8 _dstPoolId
//   ) ERC4626(asset) ERC20(name, symbol) {
//     lockupPeriod = _lockupPeriod;
//     owner = msg.sender;
//     layerZeroEndpoint = _layerZeroEndpoint;
//     dstChainId = _dstChainId;
//     vaultCustodian = _vaultCustodian;
//     srcPoolId = _srcPoolId;
//     dstPoolId = _dstPoolId;
//   }

//   // Update lockup period (only owner)
//   function updateLockupPeriod(uint256 newLockupPeriod) external onlyOwner {
//     lockupPeriod = newLockupPeriod;
//     emit LockupPeriodUpdated(newLockupPeriod);
//   }

//   // Deposit into the vault and update rewards
//   function deposit(
//     uint256 assets,
//     address receiver
//   ) public nonReentrant updateReward(receiver) returns (uint256) {
//     require(launchTime == 0, 'Vault already launched');
//     uint256 shares = super.deposit(assets, receiver);
//     emit Deposited(receiver, assets);
//     return shares;
//   }

//   function launch() external payable onlyOwner {
//     require(!isLaunched, 'Already launched');
//     require(totalAssets() > 0, 'No assets to launch');

//     isLaunched = true;
//     launchTimestamp = block.timestamp;

//     uint256 totalAmount = totalAssets();
//     bytes memory payload = abi.encode(targetVaultCustodian, totalAmount); // send payload of custodian and amount

//     // Prepare Stargate parameters
//     IStargateRouter.lzTxObj memory lzTxParams = IStargateRouter.lzTxObj(
//       0, // Gas limit on destination
//       0, // Gas price on destination
//       bytes('')
//     );

//     bytes memory payload = abi.encode(address(this), totalAmount);

//     stargateRouter.swap{value: msg.value}(
//       dstChainId, // destination chainId
//       srcPoolId, // source pool id
//       dstPoolId, // destination pool id
//       payable(address(this)), // refund address
//       totalAmount, // quantity to swap
//       0, // amountMin - minimum amount to receive on destination
//       lzTxParams, // LayerZero tx parameters
//       abi.encodePacked(vaultCustodian), // destination address
//       payload // additional payload
//     );

//     emit Bridged(amount, targetChainId, targetVaultCustodian);
//   }

//   function requestWithdrawal() external payable nonReentrant {
//     require(isLaunched, 'Vault not launched');
//     require(
//       block.timestamp >= depositTimestamps[msg.sender] + lockupPeriod,
//       'Lock period not ended'
//     );

//     uint256 shares = balanceOf(msg.sender);
//     require(shares > 0, 'No shares to withdraw');

//     bytes memory payload = abi.encode(msg.sender, shares);
//     uint256 fee = lzEndpoint.estimateFees(dstChainId, address(this), payload, false, '');
//     require(msg.value > fee);

//     lzEndpoint.send{value: fee}(
//       dstChainId,
//       abi.encodePacked(vaultCustodian),
//       payload,
//       payable(address(this)),
//       address(0),
//       bytes('')
//     );
//   }

//   // // Calculate rewards per token
//   // function rewardPerToken() public view returns (uint256) {
//   //   if (totalSupply() == 0) return rewardPerTokenStored;
//   //   return
//   //     rewardPerTokenStored +
//   //     (rewardRate * (block.timestamp - lastUpdateTime) * 1e18) /
//   //     totalSupply();
//   // }

//   // // Calculate earned rewards for a user
//   // function earned(address account) public view returns (uint256) {
//   //   return
//   //     (balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) /
//   //     1e18 +
//   //     rewards[account];
//   // }

//   // Fallback to receive LayerZero messages
//   function lzReceive(
//     uint16 _srcChainId,
//     bytes memory _srcAddress,
//     uint64 _nonce,
//     bytes memory _payload
//   ) external {
//     require(msg.sender == address(lzEndpoint), 'Invalid endpoint');
//     require(_srcChainId == dstChainId, 'Invalid source chain');

//     bytes32 messageId = keccak256(abi.encodePacked(_srcChainId, _srcAddress, _nonce));
//     require(!completedMessages[messageId], 'Message already processed');

//     completedMessages[messageId] = true;

//     (address user, uint256 shares) = abi.decode(_payload, (address, uint256));
//     _burn(user, shares);
//   }
// }
