// SPDX-License-Identifier: GPL-2.0-or-later

// adapted from https://github.com/Synthetixio/synthetix/blob/c53070db9a93e5717ca7f74fcaf3922e991fb71b/contracts/StakingRewards.sol
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {Owned} from "@solmate/auth/Owned.sol";

import {Math as MavMath} from "@maverick/libraries/Math.sol";
import {BitMap} from "@maverick/libraries/BitMap.sol";

import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";

/*
@dev the rewards distributor contract, adapted from Maverick AMM https://etherscan.deth.net/address/0x743392B6D0A9b6a5355fd83eB806861D401ea411#code
*/

abstract contract Rewarder is IRewarder, ReentrancyGuard, Owned, Multicall {
    using SafeERC20 for IERC20;
    using BitMap for BitMap.Instance;

    uint8 public constant MAX_REWARD_TOKENS = 16;

    uint256 constant ONE = 1e18;

    // Max Duration of rewards to be paid out
    uint256 constant MAX_DURATION = 30 days;
    uint256 constant MIN_DURATION = 3 days;

    // Total staked
    uint256 public totalStakes;
    // User address => staked amount
    mapping(address => uint256) public stakeOf;

    RewardData[] public rewardData;
    mapping(address => uint8) public tokenIndex;
    mapping(address token => bool approved) public isApprovedRewardToken;
    mapping(address token => uint256 duration) public rewardDuration;

    BitMap.Instance public globalActive;

    constructor(address _owner) Owned(_owner) {
        // push empty token so that we can use index zero as a sentinel value
        // in tokenIndex mapping; ie if tokenIndex[X] = 0, we know X is not in
        // the list
        rewardData.push();
    }

    modifier checkAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /////////////////////////////////////
    /// View Functions
    /////////////////////////////////////

    function rewardInfo() external view returns (RewardInfo[] memory info) {
        uint256 length = rewardData.length;
        info = new RewardInfo[](length);
        for (uint8 i = 1; i < length; i++) {
            RewardData storage data = rewardData[i];
            info[i] = RewardInfo({minimumAmount: data.minimumAmount, finishAt: data.finishAt, updatedAt: data.updatedAt, rewardRate: data.rewardRate, rewardPerTokenStored: data.rewardPerTokenStored, rewardToken: data.rewardToken});
        }
    }

    function earned(address account) public view returns (EarnedInfo[] memory earnedInfo) {
        uint256 length = rewardData.length;
        earnedInfo = new EarnedInfo[](length);
        for (uint8 i = 1; i < length; i++) {
            RewardData storage data = rewardData[i];
            earnedInfo[i] = EarnedInfo({account: account, earned: earned(account, data), rewardToken: data.rewardToken});
        }
    }

    function earned(address account, address rewardTokenAddress) external view returns (uint256) {
        uint256 rewardTokenIndex = tokenIndex[rewardTokenAddress];
        if (rewardTokenIndex == 0) revert NotValidRewardToken(rewardTokenAddress);
        RewardData storage data = rewardData[rewardTokenIndex];
        return earned(account, data);
    }

    function earned(address account, RewardData storage data) internal view returns (uint256) {
        return data.rewards[account] + Math.mulDiv(stakeOf[account], MavMath.clip(data.rewardPerTokenStored + deltaRewardPerToken(data), data.userRewardPerTokenPaid[account]), ONE);
    }

    /////////////////////////////////////
    /// Internal Update Functions
    /////////////////////////////////////

    function updateReward(address account, RewardData storage data) internal {
        uint256 reward = deltaRewardPerToken(data);
        if (reward != 0) {
            data.rewardPerTokenStored += reward;
            data.escrowedReward += Math.mulDiv(reward, totalStakes, ONE, Math.Rounding(1));
        }
        data.updatedAt = lastTimeRewardApplicable(data.finishAt);

        if (account != address(0)) {
            if (data.resetCount[account] != data.globalResetCount) {
                // check to see if this token index was changed
                data.userRewardPerTokenPaid[account] = 0;
                data.rewards[account] = 0;
                data.resetCount[account] = data.globalResetCount;
            }
            data.rewards[account] += deltaEarned(account, data);
            data.userRewardPerTokenPaid[account] = data.rewardPerTokenStored;
        }
    }

    function deltaEarned(address account, RewardData storage data) internal view returns (uint256) {
        return Math.mulDiv(stakeOf[account], MavMath.clip(data.rewardPerTokenStored, data.userRewardPerTokenPaid[account]), ONE);
    }

    function deltaRewardPerToken(RewardData storage data) internal view returns (uint256) {
        uint256 timeDiff = MavMath.clip(lastTimeRewardApplicable(data.finishAt), data.updatedAt);
        if (timeDiff == 0 || totalStakes == 0 || data.rewardRate == 0) {
            return 0;
        }
        return Math.mulDiv(data.rewardRate, timeDiff * ONE, totalStakes);
    }

    function lastTimeRewardApplicable(uint256 dataFinishAt) internal view returns (uint256) {
        return Math.min(dataFinishAt, block.timestamp);
    }

    function updateAllRewards(address account) internal {
        uint256 length = rewardData.length;
        for (uint8 i = 1; i < length; i++) {
            if (!globalActive.get(i)) continue;

            RewardData storage data = rewardData[i];

            updateReward(account, data);
        }
    }

    function _updateStakes(address from, address to, uint256 amount) internal {
        stakeOf[from] -= amount;
        stakeOf[to] += amount;
    }

    /////////////////////////////////////
    /// Internal User Functions
    /////////////////////////////////////

    function _stake(uint256 amount, address account) internal nonReentrant checkAmount(amount) {
        updateAllRewards(account);
        stakeOf[account] += amount;
        totalStakes += amount;
        emit Stake(msg.sender, msg.sender, amount, account, stakeOf[account], totalStakes);
    }

    function _unstake(uint256 amount, address account) internal nonReentrant checkAmount(amount) {
        updateAllRewards(account);
        stakeOf[account] -= amount;
        totalStakes -= amount;
        emit Unstake(msg.sender, account, amount, msg.sender, stakeOf[account], totalStakes);
    }

    function _getReward(address account, address recipient, uint8 rewardTokenIndex) internal nonReentrant returns (uint256 reward) {
        if (!globalActive.get(rewardTokenIndex)) revert StaleToken(rewardTokenIndex);
        RewardData storage data = rewardData[rewardTokenIndex];
        updateReward(account, data);
        reward = data.rewards[account];
        if (reward != 0) {
            data.rewards[account] = 0;
            data.escrowedReward -= reward;
            data.rewardToken.safeTransfer(recipient, reward);
        }
        emit GetReward(msg.sender, account, recipient, rewardTokenIndex, address(data.rewardToken), reward);
    }

    function _getReward(address account, address recipient, uint8[] memory rewardTokenIndices) internal {
        uint256 length = rewardTokenIndices.length;
        for (uint8 i; i < length; i++) {
            _getReward(account, recipient, rewardTokenIndices[i]);
        }
    }

    /////////////////////////////////////
    /// Add Reward
    /////////////////////////////////////

    /// @notice Adds reward to contract.
    function notifyAndTransfer(address rewardTokenAddress, uint256 amount) public nonReentrant {
        _notifyRewardAmount(rewardTokenAddress, amount);
        IERC20(rewardTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    /* @notice called by reward depositor to recompute the reward rate.  If
     *  notifier sends more than remaining amount, then notifier sets the rate.
     *  Else, we extend the duration at the current rate. We may notify with less
     *  than enough of assets to cover the period. In that case, reward rate will
     *  be 0 and the assets sit on the contract until another notify happens with
     *  enough assets for a positive rate.
     *   @dev Must notify before transfering assets.  Transfering and then
     *  notifying with the same amount will break the logic of this reward
     *  contract.  If a contract needs to transfer and then notify, the
     *  notification amount should be 0.
     */
    function _notifyRewardAmount(address rewardTokenAddress, uint256 amount) internal {
        uint8 rewardTokenIndex = tokenIndex[rewardTokenAddress];
        RewardData storage data = rewardData[rewardTokenIndex];
        if (!isApprovedRewardToken[rewardTokenAddress]) revert NotValidRewardToken(rewardTokenAddress);
        uint256 minimumAmount = data.minimumAmount;
        if (amount < minimumAmount) revert RewardAmountBelowThreshold(amount, minimumAmount);

        updateReward(address(0), data);
        uint256 remainingRewards = MavMath.clip(data.rewardToken.balanceOf(address(this)), data.escrowedReward);
        uint256 duration;
        if (amount > remainingRewards || data.rewardRate == 0) {
            // if notifying new amount, notifier gets to set the rate
            duration = rewardDuration[rewardTokenAddress];
            data.rewardRate = (amount + remainingRewards) / duration;
        } else {
            // if notifier doesn't bring enough, we extend the duration at the
            // same rate
            duration = (amount + remainingRewards) / data.rewardRate;
        }
        if (duration > MAX_DURATION) revert DurationOutOfBounds(duration);
        data.finishAt = block.timestamp + duration;
        data.updatedAt = block.timestamp;
        emit NotifyRewardAmount(msg.sender, rewardTokenAddress, amount, duration, data.rewardRate);
    }

    /////////////////////////////////////
    /// Admin Function
    /////////////////////////////////////

    function addNewRewardToken(address rewardTokenAddress, uint256 minimumAmount, uint256 duration) external onlyOwner returns (uint8 index) {
        index = _addNewRewardToken(rewardTokenAddress, minimumAmount, duration);
    }
    
    function removeStaleToken(address rewardTokenAddress) public virtual onlyOwner {
        _removeStaleToken(tokenIndex[rewardTokenAddress]);
        isApprovedRewardToken[rewardTokenAddress] = false;
    }

    function updateRewardDuration(address rewardTokenAddress, uint256 duration) external onlyOwner {
        uint8 index = tokenIndex[rewardTokenAddress];
        RewardData storage data = rewardData[index];
        if (block.timestamp < data.finishAt) revert RewardsNotEnded(data.finishAt);
        rewardDuration[rewardTokenAddress] = duration;
        emit DurationUpdated(rewardTokenAddress, duration);
    }

    /// @dev add token if it is approved and is not already tracked
    function _addNewRewardToken(address rewardTokenAddress, uint256 minimumAmount, uint256 duration) internal returns (uint8 rewardTokenIndex) {
        rewardTokenIndex = tokenIndex[rewardTokenAddress];
        if (rewardTokenIndex != 0) return rewardTokenIndex;

        // find first unset token index and use it
        for (uint8 i = 1; i < MAX_REWARD_TOKENS + 1; i++) {
            if (globalActive.get(i)) continue;
            rewardTokenIndex = i;
            break;
        }
        if (rewardTokenIndex == 0) revert TooManyRewardTokens();
        if (rewardTokenIndex == rewardData.length) rewardData.push();

        RewardData storage _data = rewardData[rewardTokenIndex];

        _data.rewardToken = IERC20(rewardTokenAddress);
        _data.globalResetCount++;
        _data.minimumAmount = minimumAmount;

        tokenIndex[rewardTokenAddress] = rewardTokenIndex;
        globalActive.set(rewardTokenIndex);

        isApprovedRewardToken[rewardTokenAddress] = true;
        rewardDuration[rewardTokenAddress] = duration;
        emit NewRewardTokenAdded(rewardTokenAddress, minimumAmount, duration);
    }

    function _removeStaleToken(uint8 rewardTokenIndex) internal {
        RewardData storage data = rewardData[rewardTokenIndex];
        emit RemoveRewardToken(address(data.rewardToken), rewardTokenIndex);

        // remove token from list
        globalActive.unset(rewardTokenIndex);
        delete tokenIndex[address(data.rewardToken)];

        delete data.rewardToken;
        delete data.escrowedReward;
        delete data.rewardPerTokenStored;
        delete data.rewardRate;
        delete data.finishAt;
        delete data.updatedAt;
        delete data.minimumAmount;

        delete rewardDuration[address(data.rewardToken)];
    }
}