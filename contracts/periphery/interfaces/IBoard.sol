// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IReward} from "@maverick/interfaces/IReward.sol";

import {IFees} from "contracts/periphery/interfaces/IFees.sol";

interface IBoard is IFees {
    
    error InvalidVoteFee(uint256 voteFee);
    error LengthNotMatching(uint256 poolLength, uint256 rewardTokenLength);
    error InvalidVoteToken(address voteToken);
    error UnmatchedLength(uint256 _poolsLength, uint256 _weightsLength);
    error InvalidPool(address pool);
    error InvalidWeights(uint256 _totalWeights);
    error InvalidPeriod(uint256 _lastVote, uint256 _period);
    error PoolAlreadyAdded(uint8 _poolIndex);
    error NotOwnerOrDelegate(address caller, address voteToken);
    error LockCreated();

    event PoolAdded(address pool, uint8 poolIndex);
    event PoolRemoved(address pool, uint8 poolIndex);
    event Vote(address account, address voteToken, IReward[] pools, uint256[] weights);
    event VoteFeeUpdated(uint256 voteFee);
    event BountyFeeUpdated(uint256 bountyFee);

    struct RewardInfo {
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


    struct RewardData {
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

    function unstake(address lpReward, uint256 amount, address receiver) external;
    function extendLockup(uint256 amount) external;
    function isBoard() external returns (bool);
    function poolIndex(address pool) external returns (uint8);
    function lastVote(address account) external returns (uint256);
    function lastPoolVote(address account, address pool) external returns (uint256);
    function votesOf(address account, address pool) external returns (uint256);
    function bountyFee() external returns (uint256);
    function totalVotes(address pool) external returns (uint256);

}