// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {

    /// @notice Emitted when a new reward token is added to the contract
    event NewRewardTokenAdded(address rewardToken, uint256 minimumAmount, uint256 duration);
    /// @notice Emitted when a reward is sent to the contract
    event NotifyRewardAmount(address sender, address rewardTokenAddress, uint256 amount, uint256 duration, uint256 rewardRate);
    /// @notice Emitted when rewards are claimed by an account 
    event GetReward(address sender, address account, address recipient, uint8 rewardTokenIndex, address rewardTokenAddress, uint256 rewardPaid);
    /// @notice Emitted when an account unstake from the contract
    event Unstake(address sender, address account, uint256 amount, address recipient, uint256 userBalance, uint256 totalSupply);
    /// @notice Emitted when an account stake in the contract
    event Stake(address sender, address supplier, uint256 amount, address account, uint256 userBalance, uint256 totalSupply);
    /// @notice Emitted when a reward token is removed from the contract
    event RemoveRewardToken(address rewardTokenAddress, uint8 rewardTokenIndex);
    /// @notice Emitted when a reward token duration is updated
    event DurationUpdated(address rewardTokenAddress, uint256 duration);


    error DurationOutOfBounds(uint256 duration);
    error ZeroAmount();
    error NotValidRewardToken(address rewardTokenAddress);
    error TooManyRewardTokens();
    error StaleToken(uint8 rewardTokenIndex);
    error TokenNotStale(uint8 rewardTokenIndex);
    error RewardStillActive(uint8 rewardTokenIndex);
    error RewardAmountBelowThreshold(uint256 amount, uint256 minimumAmount);
    error InvalidTokenRecovery();
    error RewardsNotEnded(uint256 finishAt);
    error InvalidCaller(address caller);
    error InvalidLength();
    
    struct RewardData {
        // Minimum amount of reward token to be added
        uint256 minimumAmount;
        // Timestamp of when the rewards finish
        uint256 finishAt;
        // Minimum of last updated time and reward finish time
        uint256 updatedAt;
        // Reward to be paid out per second
        uint256 rewardRate;
        // Sum of (reward rate * dt * 1e18 / total supply)
        uint256 rewardPerTokenStored;
        // User address => rewardPerTokenStored
        mapping(address => uint256) userRewardPerTokenPaid;
        // User address => rewards to be claimed
        mapping(address => uint256) rewards;
        // User address => rewards mapping to track if token index has been
        // updated
        mapping(address => uint256) resetCount;
        // total earned
        uint256 escrowedReward;
        uint256 globalResetCount;
        IERC20 rewardToken;
    }

    struct RewardInfo {
        // Minimum amount of reward token to be added
        uint256 minimumAmount;
        // Timestamp of when the rewards finish
        uint256 finishAt;
        // Minimum of last updated time and reward finish time
        uint256 updatedAt;
        // Reward to be paid out per second
        uint256 rewardRate;
        // Sum of (reward rate * dt * 1e18 / total supply)
        uint256 rewardPerTokenStored;
        IERC20 rewardToken;
    }

    struct EarnedInfo {
        // account
        address account;
        // earned
        uint256 earned;
        // reward token
        IERC20 rewardToken;
    }

    // /// @notice oROG contract
    // function orog() external view returns (IoROG);

    // /// @notice the option claim address
    // function optionClaim() external view returns (address);

    /// @notice the total amount of staking token staked in the contract
    function totalStakes() external view returns (uint256);

    /// @notice the amount of stakes owned by an account
    /// @param account address of the account
    function stakeOf(address account) external view returns (uint256);

    /// @notice the staking token staking contract
    function rewardInfo() external view returns (RewardInfo[] memory);

    /// @notice the index of a token in the array of reward tokens
    /// @param tokenAddress address of the token
    /// @return index of the token
    function tokenIndex(address tokenAddress) external view returns (uint8);

    /// @notice returns true if a token is in the array of reward tokens
    /// @param token address of the token
    /// @return true if token is in the array of reward tokens
    function isApprovedRewardToken(address token) external view returns (bool);

    function rewardDuration(address token) external view returns (uint256);

    /// @notice view to get the amount of earned rewards for an account
    /// @param account address of the account
    /// @param rewardTokenAddress address of the reward token
    /// @return amount of earned rewards
    function earned(address account, address rewardTokenAddress) external view returns (uint256);

    /// @notice view to get the amount of earned rewards for an account
    /// @param account address of the account
    function earned(address account) external view returns (EarnedInfo[] memory earnedInfo);

    /// @notice Add rewards tokens account the pot of rewards with a transferFrom.
    /// @param  rewardTokenAddress address of reward token added
    function notifyAndTransfer(address rewardTokenAddress, uint256 amount) external;

    /// @notice Get reward proceeds for transaction sender account `account`.
    /// @param recipient Receiver of REWARD_TOKEN rewards.
    /// @param rewardTokenIndices indices of reward tokens to collect
    function getReward(address recipient, uint8[] calldata rewardTokenIndices) external;

    /// @notice Get reward proceeds for transaction sender account `account`.
    /// @param recipient Receiver of REWARD_TOKEN rewards.
    /// @param rewardTokenIndex index of reward token to collect
    function getReward(address recipient, uint8 rewardTokenIndex) external returns (uint256);

    /// @notice Add a new reward token to the contract
    /// @param rewardTokenAddress address of reward token added
    /// @param minimumAmount minimum amount of reward token to be added
    /// @param duration duration of the reward period
    function addNewRewardToken(address rewardTokenAddress, uint256 minimumAmount, uint256 duration) external returns (uint8);

    /// @notice Remove stale tokens from the reward contract
    /// @param rewardTokenAddress is the index of the reward token in the
    //tokenIndex mapping
    function removeStaleToken(address rewardTokenAddress) external;

    /// @notice update the reward duration for a reward token
    /// @param rewardTokenAddress address of reward token added
    /// @param duration duration of the reward period
    function updateRewardDuration(address rewardTokenAddress, uint256 duration) external;
}