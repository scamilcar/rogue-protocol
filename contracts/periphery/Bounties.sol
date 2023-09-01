// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Adapted from StakeDAO https://etherscan.deth.net/address/0x0000000895cB182E6f983eb4D8b4E0Aa0B31Ae4c

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";
import {IBounties} from "contracts/periphery/interfaces/IBounties.sol";

// TODO change block.timestamp to block.number?
// TODO remove blacklisted addresses from totalVotes calculation like inspiration
// TODO adapt to Maverick periods

contract Bounties is IBounties, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    /// @notice the board contract address
    IBoard public immutable board;

    /// @notice month in seconds
    uint256 public constant MONTH = 30 days;

    /// @notice Minimum duration of a Bounty.
    uint256 public MINIMUM_PERIOD = 1;

    /// @notice 100%
    uint256 public constant ONE = 1e18;

    /// @notice Bounty ID Counter.
    uint256 public nextId;

    /// @notice ID => Bounty.
    mapping(uint256 id => Bounty bounty) public bounties;

    /// @notice ID => Period running.
    mapping(uint256 id => Period) public activePeriod;

    /// @notice ID => Amount of reward per vote distributed.
    mapping(uint256 id => uint256) public rewardPerVote;

    /// @notice ID => Amount Claimed per Bounty.
    mapping(uint256 id => uint256) public amountClaimed;

    /// @notice Last time a user claimed
    mapping(address user => mapping(uint256 id => uint256 period)) public lastUserClaim;

    /// @notice Recipient per address.
    mapping(address user => address recipient) public recipient;

    /// @notice BountyId => isUpgradeable. If true, the bounty can be upgraded.
    mapping(uint256 => bool) public isUpgradeable;

    /// @notice ID => Bounty In Queue to be upgraded.
    mapping(uint256 => Upgrade) public upgradeBountyQueue;

    // fee 
    mapping(address => uint256) public feeAccrued;

    /// @param _board Address of the board contract.
    constructor(address _board) {
        board = IBoard(_board);
        ++nextId;
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Modifier ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice check if the caller is the manager of the bounty
    /// @param _id ID of the bounty.
    modifier onlyManager(uint256 _id) {
        if (msg.sender != bounties[_id].manager) revert NotManager(msg.sender, _id);
        _;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// View //////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Return the bounty object for a given ID.
    /// @param bountyId ID of the bounty.
    function getBounty(uint256 bountyId) external view returns (Bounty memory) {
        return bounties[bountyId];
    }

    // TODO adapt to Maverick
    /// @notice Return the current period based on Gauge Controller rounding.
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / MONTH) * MONTH;
    }

    /// @notice Return the expected current period id.
    /// @param bountyId ID of the bounty.
    function getActivePeriodPerBounty(uint256 bountyId) public view returns (uint8) {
        Bounty storage bounty = bounties[bountyId];

        uint256 currentPeriod = getCurrentPeriod();
        uint256 periodsLeft = bounty.endTimestamp > currentPeriod ? (bounty.endTimestamp - currentPeriod) / MONTH : 0;
        // If periodsLeft is superior, then the bounty didn't start yet.
        return uint8(periodsLeft > bounty.numberOfPeriods ? 0 : bounty.numberOfPeriods - periodsLeft);
    }

    /// @notice Returns the number of periods left for a given bounty.
    /// @param bountyId ID of the bounty.
    function getPeriodsLeft(uint256 bountyId) public view returns (uint256 periodsLeft) {
        Bounty storage bounty = bounties[bountyId];

        uint256 currentPeriod = getCurrentPeriod();
        periodsLeft = bounty.endTimestamp > currentPeriod ? (bounty.endTimestamp - currentPeriod) / MONTH : 0;
    }

    /// @notice Return the active period running of bounty given an ID.
    /// @param bountyId ID of the bounty.
    function getActivePeriod(uint256 bountyId) public view returns (Period memory) {
        return activePeriod[bountyId];
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// User Facing //////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Create a new bounty.
    /// @param pool Address of the target gauge.
    /// @param rewardToken Address of the ERC20 used or rewards.
    /// @param totalRewardAmount Total Reward Added.
    /// @param numberOfPeriods Number of periods.
    /// @param maxRewardPerVote Target Bias for the Gauge.
    /// @param manager Manager.
    /// @return bountyId of the bounty created.
    function create(
        address pool,
        address rewardToken,
        uint256 totalRewardAmount, 
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote, 
        address manager
    ) external returns (uint256 bountyId) {
        if (board.poolIndex(pool) == 0) return bountyId;
        if (numberOfPeriods < MINIMUM_PERIOD) revert WrongNumberOfPeriods();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert WrongInput();
        if (rewardToken == address(0) || manager == address(0)) revert ZeroAddress();

        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bounty and increment the nextID counter.
            bountyId = nextId;

            ++nextId;
        }

        uint256 rewardPerPeriod = totalRewardAmount / numberOfPeriods;
        uint256 currentPeriod = getCurrentPeriod();

        bounties[bountyId] = Bounty({
            pool: pool,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            endTimestamp: currentPeriod + ((numberOfPeriods + 1) * MONTH),
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount
        });

        emit BountyCreated(
            bountyId,
            pool,
            manager,
            rewardToken,
            numberOfPeriods,
            maxRewardPerVote,
            rewardPerPeriod,
            totalRewardAmount
        );

        // Starting from next period.
        activePeriod[bountyId] = Period(0, currentPeriod + MONTH, rewardPerPeriod);
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    function claim(uint256 bountyId) external returns (uint256) {
        return _claim(msg.sender, msg.sender, bountyId);
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    function claim(uint256 bountyId, address _recipient) external returns (uint256) {
        return _claim(msg.sender, _recipient, bountyId);
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    function claimFor(address user, uint256 bountyId) external returns (uint256) {
        address _recipient = recipient[user];
        return _claim(user, _recipient != address(0) ? _recipient : user, bountyId);
    }

    /// @notice Claim all rewards for multiple bounties.
    /// @param ids Array of bounty IDs to claim.
    function claimAll(uint256[] calldata ids) external {
        uint256 length = ids.length;

        for (uint256 i = 0; i < length;) {
            uint256 id = ids[i];

            _claim(msg.sender, msg.sender, id);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim all rewards for multiple bounties to a given recipient.
    /// @param ids Array of bounty IDs to claim.
    /// @param _recipient Address to send the rewards to.
    function claimAll(uint256[] calldata ids, address _recipient) external {
        uint256 length = ids.length;

        for (uint256 i = 0; i < length;) {
            uint256 id = ids[i];
            _claim(msg.sender, _recipient, id);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim all rewards for multiple bounties on behalf of a user.
    /// @param ids Array of bounty IDs to claim.
    /// @param _user Address to claim the rewards for.
    function claimAllFor(address _user, uint256[] calldata ids) external {
        address _recipient = recipient[_user];
        uint256 length = ids.length;

        for (uint256 i = 0; i < length;) {
            uint256 id = ids[i];
            _claim(_user, _recipient != address(0) ? _recipient : _user, id);
            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Internal ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bounty.
    /// @param _user Address of the user.
    /// @param _recipient Address of the recipient.
    /// @param _bountyId ID of the bounty.
    /// @return amount of rewards claimed.
    function _claim(address _user, address _recipient, uint256 _bountyId)
        internal
        nonReentrant
        returns (uint256 amount)
    {
        // Update if needed the current period.
        uint256 currentPeriod = _updateBountyPeriod(_bountyId);

        Bounty storage bounty = bounties[_bountyId];

        uint256 lastVote = board.lastPoolVote(_user, bounty.pool);
        uint256 userVotes = board.votesOf(_user, bounty.pool); // question is it safe? can't we game by voting last minute?

        if (
            userVotes == 0 || lastUserClaim[_user][_bountyId] >= currentPeriod
            || currentPeriod <= lastVote || currentPeriod >= bounty.endTimestamp
            || currentPeriod != getCurrentPeriod() || amountClaimed[_bountyId] == bounty.totalRewardAmount
        ) return 0;

        lastUserClaim[_user][_bountyId] = currentPeriod;

        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = Math.mulDiv(userVotes, rewardPerVote[_bountyId], ONE);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = Math.mulDiv(userVotes, bounty.maxRewardPerVote, ONE);
        // Distribute the _min between the amount based on votes, and price.
        amount = Math.min(amount, _amountWithMaxPrice);

        uint256 _amountClaimed = amountClaimed[_bountyId];

        if (amount + _amountClaimed > bounty.totalRewardAmount) {
            amount = bounty.totalRewardAmount - _amountClaimed;
        }

        amountClaimed[_bountyId] += amount;

        uint256 feeAmount;
        uint256 fee = board.bountyFee();

        if (fee != 0) {
            feeAmount = Math.mulDiv(amount, fee, ONE);
            amount -= feeAmount;
            feeAccrued[bounty.rewardToken] += feeAmount;
        }

        // Transfer to user.
        IERC20(bounty.rewardToken).safeTransfer(_recipient, amount);

        emit Claimed(_user, bounty.rewardToken, _bountyId, amount, feeAmount, currentPeriod);
    }

    /// @notice Update the current period for a given bounty.
    /// @param bountyId Bounty ID.
    /// @return current/updated period.
    function _updateBountyPeriod(uint256 bountyId) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bountyId];

        uint256 currentPeriod = getCurrentPeriod();

        if (_activePeriod.id == 0 && currentPeriod == _activePeriod.timestamp) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);
            // Initialize reward per token.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bountyId);
        }

        // Increase Period
        if (block.timestamp >= _activePeriod.timestamp + MONTH) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);
            // Roll to next period.
            _rollOverToNextPeriod(bountyId, currentPeriod);

            return currentPeriod;
        }

        return _activePeriod.timestamp;
    }

    /// @notice Checks for an upgrade and update the bounty.
    function _checkForUpgrade(uint256 bountyId) internal {
        Upgrade storage upgradedBounty = upgradeBountyQueue[bountyId];

        // Check if there is an upgrade in queue.
        if (upgradedBounty.totalRewardAmount != 0) {
            // Save new values.
            bounties[bountyId].endTimestamp = upgradedBounty.endTimestamp;
            bounties[bountyId].numberOfPeriods = upgradedBounty.numberOfPeriods;
            bounties[bountyId].maxRewardPerVote = upgradedBounty.maxRewardPerVote;
            bounties[bountyId].totalRewardAmount = upgradedBounty.totalRewardAmount;

            if (activePeriod[bountyId].id == 0) {
                activePeriod[bountyId].rewardPerPeriod =
                    upgradedBounty.totalRewardAmount.mulDiv(1, upgradedBounty.numberOfPeriods);
            }

            emit BountyDurationIncrease(
                bountyId,
                upgradedBounty.numberOfPeriods,
                upgradedBounty.totalRewardAmount,
                upgradedBounty.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBountyQueue[bountyId];
        }
    }

    /// @notice Roll over to next period.
    /// @param bountyId Bounty ID.
    /// @param currentPeriod Next period timestamp.
    function _rollOverToNextPeriod(uint256 bountyId, uint256 currentPeriod) internal {
        uint8 index = getActivePeriodPerBounty(bountyId);

        Bounty storage bounty = bounties[bountyId];

        uint256 periodsLeft = getPeriodsLeft(bountyId);
        uint256 rewardPerPeriod;

        rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

        if (bounty.endTimestamp > currentPeriod + MONTH && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 votes = board.totalVotes(bounty.pool);

        rewardPerVote[bountyId] = Math.mulDiv(rewardPerPeriod, ONE, votes);
        activePeriod[bountyId] = Period(index, currentPeriod, rewardPerPeriod);

        emit PeriodRolledOver(bountyId, index, currentPeriod, rewardPerPeriod);
    }


    /// @notice Update the amount of reward per token for a given bounty.
    /// @dev This function is only called once per Bounty.
    function _updateRewardPerToken(uint256 bountyId) internal {
        if (rewardPerVote[bountyId] == 0) {
            Bounty storage bounty = bounties[bountyId];
            
            uint256 votes = board.totalVotes(bounty.pool);
            if (votes != 0) {
                rewardPerVote[bountyId] = Math.mulDiv(activePeriod[bountyId].rewardPerPeriod, ONE, votes);
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// Management ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Increase Bounty duration.
    /// @param _bountyId ID of the bounty.
    /// @param _additionnalPeriods Number of periods to add.
    /// @param _increasedAmount Total reward amount to add.
    /// @param _newMaxPricePerVote Total reward amount to add.
    function increaseBountyDuration(
        uint256 _bountyId,
        uint8 _additionnalPeriods,
        uint256 _increasedAmount,
        uint256 _newMaxPricePerVote
    ) external nonReentrant onlyManager(_bountyId) {
        if (!isUpgradeable[_bountyId]) revert NotUpgradeable();
        if (getPeriodsLeft(_bountyId) < 1) revert NoPeriodsLeft();
        if (_increasedAmount == 0 || _newMaxPricePerVote == 0) {
            revert WrongInput();
        }

        Bounty storage bounty = bounties[_bountyId];
        Upgrade memory upgradedBounty = upgradeBountyQueue[_bountyId];

        IERC20(bounty.rewardToken).safeTransferFrom(msg.sender, address(this), _increasedAmount);

        if (upgradedBounty.totalRewardAmount != 0) {
            upgradedBounty = Upgrade({
                numberOfPeriods: upgradedBounty.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: upgradedBounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: upgradedBounty.endTimestamp + (_additionnalPeriods * MONTH)
            });
        } else {
            upgradedBounty = Upgrade({
                numberOfPeriods: bounty.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: bounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: bounty.endTimestamp + (_additionnalPeriods * MONTH)
            });
        }

        upgradeBountyQueue[_bountyId] = upgradedBounty;

        emit BountyDurationIncreaseQueued(
            _bountyId, upgradedBounty.numberOfPeriods, upgradedBounty.totalRewardAmount, _newMaxPricePerVote
        );
    }

    /// @notice Close Bounty if there is remaining.
    /// @param bountyId ID of the bounty to close.
    function closeBounty(uint256 bountyId) external nonReentrant {
        // Check if the currentPeriod is the last one.
        // If not, we can increase the duration.
        Bounty storage bounty = bounties[bountyId];
        if (bounty.manager == address(0)) revert AlreadyClosed();

        if (getCurrentPeriod() >= bounty.endTimestamp) {
            uint256 leftOver;
            Upgrade memory upgradedBounty = upgradeBountyQueue[bountyId];

            if (upgradedBounty.totalRewardAmount != 0) {
                leftOver = upgradedBounty.totalRewardAmount - amountClaimed[bountyId];
                delete upgradeBountyQueue[bountyId];
            } else {
                leftOver = bounties[bountyId].totalRewardAmount - amountClaimed[bountyId];
            }

            // Transfer the left over to the owner.
            IERC20(bounty.rewardToken).safeTransfer(bounty.manager, leftOver);
            delete bounties[bountyId].manager;

            emit BountyClosed(bountyId, leftOver);
        }
    }

    /// @notice Update Bounty Manager.
    /// @param bountyId ID of the bounty.
    /// @param newManager Address of the new manager.
    function updateManager(uint256 bountyId, address newManager) external onlyManager(bountyId) {
        emit ManagerUpdated(bountyId, bounties[bountyId].manager = newManager);
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Owner /////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Claim fees.
    /// @param rewardTokens Array of reward tokens.
    function claimFees(address[] calldata rewardTokens) external nonReentrant {
        uint256 _feeAccrued;
        uint256 length = rewardTokens.length;

        for (uint256 i = 0; i < length;) {
            address rewardToken = rewardTokens[i];

            _feeAccrued = feeAccrued[rewardToken];
            delete feeAccrued[rewardToken];

            emit FeesCollected(rewardToken, _feeAccrued);

            IERC20(rewardToken).safeTransfer(board.rogueTreasury(), _feeAccrued);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Set a recipient address for calling user.
    /// @param _recipient Address of the recipient.
    /// @dev Recipient are used when calling claimFor functions. Regular claim functions will use msg.sender as recipient,
    ///  or recipient parameter provided if called by msg.sender.
    function setRecipient(address _recipient) external {
        recipient[msg.sender] = _recipient;

        emit RecipientSet(msg.sender, _recipient);
    }
}