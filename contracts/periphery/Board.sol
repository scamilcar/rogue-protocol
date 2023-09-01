// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BitMap} from "@maverick/libraries/BitMap.sol";
import {IVotingEscrow} from "@maverick/interfaces/IVotingEscrow.sol";
import {IReward} from "@maverick/interfaces/IReward.sol";

import {Fees} from "contracts/periphery/base/Fees.sol";
import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";
import {IBooster} from "contracts/core/interfaces/IBooster.sol";

/*
this contract is used to vote on differents Mavericks gaugeweights / proposals with eROG
Bpth rMAV and eROG holders can vote on this contract
*/

contract Board is IBoard, Fees {
    using SafeERC20 for IERC20;
    using BitMap for BitMap.Instance;

    uint8 public MAX_REWARD_TOKENS = 5;

    uint256 public mavLocked;
    bool public isBoard = true;
    uint256 public voteFee;
    address public poll;
    uint256 public constant PERIOD = 30 days;
    uint256 public bountyFee;
    bool public init;
    uint256 public constant maxDuration = 4 * 365 days;

    uint256 public constant INITIAL_ID = 0;

    // pools
    mapping(address => uint8) public poolIndex;
    BitMap.Instance public globalActive;
    address[] public pools;

    // votes
    mapping(address pool => uint256 votes) public totalVotes;
    mapping(address account => mapping(address pool => uint256 votes)) public votesOf;
    mapping(address => uint256) public lastVote;
    mapping(address => mapping(address => uint256)) public lastPoolVote;

    
    constructor(address _mav, address _veMav, address _poll) {
        mav = _mav;
        veMav = IVotingEscrow(_veMav);
        poll = _poll;
        IERC20(mav).safeApprove(_veMav, type(uint256).max);
        // use index 0 as sentinel value
        pools.push();
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Modifiers ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice restrict access to booster only
    modifier onlyBooster(address lpReward) {
        if (manager.rewardBooster(lpReward) != msg.sender) revert UnauthorizedBooster(msg.sender);
        _;
    }

    /// @notice restrict access to compounder only, if booster is in compound mode
    // TODO add data check ? to be sure compounders do indeed compound. need to decode swap data
    modifier checkParams(address booster) {
        (address compounder, bool compounding) = manager.boosterInfo(booster);
        if (!compounding) revert InvalidMode();
        if (compounder != msg.sender) revert UnauthorizedCompounder(msg.sender);
        _;
    }

    /// @notice restrict access if booster is not in normal mode
    modifier checkMode(address booster) {
        (,bool compounding) = manager.boosterInfo(booster);
        if (compounding) revert InvalidMode();
        _;
    }
    modifier onlyNewPeriod(address account) {
        uint256 timestamp = lastVote[account];
        if (getPeriod() < timestamp) revert InvalidPeriod(timestamp, getPeriod());
        _;
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// View ///////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice get the current period
    function getPeriod() public view returns (uint256) {
        return (block.timestamp / PERIOD) * PERIOD; // TODO What is Maverick period ? 1 month?
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Lock //////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice called by Locker to trigger lock logic
    function extendLockup(uint256 toLock) external {
        IERC20(mav).safeTransferFrom(msg.sender, address(this), toLock);
        // veMav.extend(INITIAL_ID, maxDuration, toLock, true); // TODO put back for test/prod
        mavLocked += toLock;
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Vote ///////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice 
    function vote(address account, address voteToken, IReward[] calldata _pools, uint256[] calldata weights) external onlyNewPeriod(account) {
        if (voteToken != staker || voteToken != escrow) revert InvalidVoteToken(voteToken);
        if (_pools.length != weights.length) revert UnmatchedLength(_pools.length, weights.length);
        if (msg.sender != account && msg.sender != IVotes(voteToken).delegates(account)) revert NotOwnerOrDelegate(msg.sender, voteToken);
        lastVote[account] = block.timestamp;
        uint256 power = _getPower(voteToken, account);

        uint256 _totalWeights;
        for (uint i = 0; i < _pools.length; i++) {
            if (poolIndex[address(_pools[i])] == 0) revert InvalidPool(address(_pools[i]));
            _vote(account, power, address(_pools[i]), weights[i]);
            _totalWeights += weights[i];
        }
        if (_totalWeights != ONE) revert InvalidWeights(_totalWeights);

        // TODO how to vote on Poll
        IPoll(poll).vote(0, _pools, weights);

        emit Vote(account, voteToken, _pools, weights);
    }

    function _vote(address account, uint256 power, address pool, uint256 weight) internal {
        if (poolIndex[pool] == 0) revert InvalidPool(pool);
        uint256 votes = power * weight / ONE;
        votesOf[account][pool] += votes;
        totalVotes[pool] += votes;
        lastPoolVote[account][pool] = block.timestamp;
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Boosters ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice should claim fair share of Maverick protocol fees for veMAV holders
    function claimLockFees(uint256 start, uint256 end) external {
        // claimed = poll.claimFees();
        // rewards = Math.mulDiv(rewards, allo.lock.rewards, ONE);
        // dividends = claimed - rewards;
        // IRewarder(staker).notifyAndTransfer(token, rewards);
    }

    /// @notice claims MAV rewards and notify them to booster
    function claimEmission(address booster) external checkMode(booster) {
        // claimed = poll.claim();
        // rewards = Math.mulDiv(rewards, allo.liquidity.rewards, ONE);
        // dividends = claimed - rewards;
        // IRewarder(booster).notifyAndTransfer(mav, rewards);
        // collectedMav += dividends;
    }

    /// @notice claims MAV rewards, compound them thanks to Hub and sends LP tokens to booster contract
    function compound(address booster, bytes calldata data) external checkParams(booster) {
        // rewards = poll.claim();
        // hub.compound(booster, rewards, data);
    }


    /// @notice unstake LP tokens tokens from lp reward
    /// @param lpReward the lp reward contract
    /// @param amount the amount to unstake
    /// @param receiver the address to receive the unstaked tokens
    function unstake(address lpReward, uint256 amount, address receiver) external onlyBooster(lpReward) {
        IReward(lpReward).unstake(amount, receiver);
    }

    /// @notice distribute extra incentives from associated lp reward contract
    function distributeExtra(IBooster booster) external {
        if (!manager.isBooster(address(booster))) revert NotBooster(address(booster));
        IReward lpReward = IReward(booster.lpReward());
        IReward.RewardInfo[] memory info = lpReward.rewardInfo();
        uint256 length = info.length;
        for (uint256 i = 1; i < length; i++) {
            address token = address(info[i].rewardToken);
            if (booster.isApprovedRewardToken(token)) {
                uint256 reward = lpReward.getReward(address(this), uint8(i));
                IERC20(token).safeApprove(address(booster), reward);
                booster.notifyAndTransfer(token, reward);
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// Internal ////////////////////////////
    ////////////////////////////////////////////////////////////////

    function _getPower(address voteToken, address account) internal view returns (uint256) {
        (,, uint256 totalPoints) = veMav.lockups(address(this), 0);
        uint256 power = IVotes(voteToken).getVotes(account);
        uint256 unit;
        if (voteToken == staker) {
            unit = Math.mulDiv(totalPoints, ONE - voteFee, ONE) / IERC20(staker).totalSupply();
        } else {
            unit = Math.mulDiv(totalPoints, voteFee, ONE) / IERC20(escrow).totalSupply();
        }
        return power * unit;
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// Restricted ///////////////////////////
    ////////////////////////////////////////////////////////////////

     /// @notice should create an initial lock
    function initialLock(uint256 amount) external onlyOwner {
        if (init) revert LockCreated();
        IERC20(mav).safeTransferFrom(msg.sender, address(this), amount);
        veMav.stake(amount, maxDuration, true);
        init = true;
    }

    function addPool(address pool) external onlyOwner {
        uint8 _poolIndex = poolIndex[pool];
        uint256 length = pools.length;
        if (_poolIndex != 0) revert PoolAlreadyAdded(_poolIndex);
        for (uint8 i = 1; i < length + 1; i++) { // question + 1 here?
            if (globalActive.get(i)) continue;
            _poolIndex = i;
            break;
        }
        if (_poolIndex == length) pools.push();
        poolIndex[pool] = _poolIndex;
        globalActive.set(_poolIndex);

        emit PoolAdded(pool, _poolIndex);
    }

    function removePool(address pool) external onlyOwner {
        uint8 _poolIndex = poolIndex[pool];
        if (_poolIndex == 0) revert InvalidPool(pool);
        globalActive.unset(_poolIndex);
        delete poolIndex[pool];
        delete totalVotes[pool];

        emit PoolRemoved(pool, _poolIndex);
    }

    function removePool() external onlyOwner {}

    /// @notice should update the repartion of voting power between eROG and rMAV
    /// question is it safe to update this?
    function updateVoteFee(uint256 _voteFee) external onlyOwner {
        if (_voteFee < 2 || _voteFee > 10) revert InvalidVoteFee(_voteFee);
        voteFee = _voteFee;

        emit VoteFeeUpdated(_voteFee);
    }

    function updateBountyFee(uint256 _bountyFee) external onlyOwner {
        emit BountyFeeUpdated(_bountyFee);
    }

    
}



interface IPoll {
    function vote(uint256 id, IReward[] calldata _pools, uint256[] calldata weights) external;
}

    