// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBounties {
    error WrongNumberOfPeriods();
    error WrongInput();
    error ZeroAddress();
    error NotManager(address caller, uint256 bountyId);
    error NotUpgradeable();
    error NoPeriodsLeft();
    error AlreadyClosed();

    event BountyCreated(
        uint256 bountyId,
        address pool,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 rewardPerPeriod,
        uint256 totalRewardAmount
    );
    event PeriodRolledOver(uint256 bountyId, uint8 index, uint256 timestamp, uint256 rewardPerPeriod);
    event Claimed(address user, address rewardToken, uint256 bountyId, uint256 amount, uint256 feeAmount, uint256 period);
    event FeesCollected(address rewardToken, uint256 amount);
    event FeeUpdated(uint256 fee);
    event RecipientSet(address user, address recipient);
    event BountyDurationIncreaseQueued(uint256 bountyId, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote);
    event BountyDurationIncrease(uint256 bountyId, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote);
    event BountyClosed(uint256 bountyId, uint256 leftOver);
    event ManagerUpdated(uint256 bountyId, address manager);

    /// @notice Bounty struct requirements.
    struct Bounty {
        // Address of the target gauge
        address pool;
        // Manager
        address manager;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // Number of periods.
        uint8 numberOfPeriods;
        // Timestamp where the bounty become unclaimable.
        uint256 endTimestamp;
        // Max Price per vote.
        uint256 maxRewardPerVote;
        // Total Reward Added.
        uint256 totalRewardAmount;
    }

    struct Upgrade {
        // Number of periods after increase.
        uint8 numberOfPeriods;
        // Total reward amount after increase.
        uint256 totalRewardAmount;
        // New max reward per vote after increase.
        uint256 maxRewardPerVote;
        // New end timestamp after increase.
        uint256 endTimestamp;
    }

    /// @notice Period struct.
    struct Period {
        // Period id.
        // Eg: 0 is the first period, 1 is the second period, etc.
        uint8 id;
        // Timestamp of the period start.
        uint256 timestamp;
        // Reward amount distributed during the period.
        uint256 rewardPerPeriod;
    }
}