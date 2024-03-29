// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/governance/utils/Votes.sol";

import {Rewarder} from "contracts/core/base/Rewarder.sol";
import {IBase} from "contracts/periphery/interfaces/IBase.sol";
import {ICouncil} from "contracts/periphery/interfaces/ICouncil.sol";

// TODO allows for rewards compounding
// TODO add events
// TODO nonReentrant?

contract Council is ICouncil, ERC4626, Rewarder, Votes {
    using SafeERC20 for IERC20;

    address public immutable broker;
    Params public params;
    uint256 public MAX_EXIT_DURATION = 365 days;

    mapping(address user => ExitInfo[] exits) public userExits;
    mapping(address user => uint256 shares) public exiting;

    mapping(address reward => bool mode) public rewardsMode;

    constructor(IERC20 _stakingToken, address _broker, address _owner)
        ERC4626(_stakingToken)
        ERC20("Dividend Rogue", "dROG") 
        Rewarder(_owner)
        EIP712("Dividend Rogue", "1") {

        broker = _broker;
    }

    /// @notice Check if a redeem entry exists
    modifier checkExit(address user, uint256 index) {
        if (index >= userExits[user].length) revert InvalidExit();
        _;
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////////// View ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice get the amount of assets received based on the duration of the exit
    /// @param shares amount of shares to exit
    /// @param duration duration of exit
    function getExitShares(uint256 shares, uint256 duration) public view returns(uint256) {
        if(duration < params.minExitDuration) {
            return 0;
        }
        if (duration > params.maxExitDuration) {
            return Math.mulDiv(shares, params.maxExitRatio, ONE);
        }
        uint256 ratio = params.minExitRatio + 
            ((duration - params.minExitDuration) * (params.maxExitRatio - params.minExitRatio)) / (params.maxExitDuration - params.minExitDuration);

        return Math.mulDiv(shares, ratio, ONE);
    }

    /// @notice get the number of current exits for a user
    /// @param user address of user
    function getUserExitsLength(address user) external view returns (uint256) {
        return userExits[user].length;
    }

    /// @notice returns the user exit struct at the given index
    function getUserExit(address user, uint256 index) external view checkExit(user, index) returns (ExitInfo memory info) {
        info = userExits[user][index];
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// User-Facing ////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice ERC4626 override
    /// @param assets amount of assets to withdraw
    /// @param receiver address to receive shares
    /// @param owner address of owner
    /// @param duration duration of exit 
    function withdraw(uint256 assets, address receiver, address owner, uint256 duration) external {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        uint256 shares = previewWithdraw(assets);
        _exit(_msgSender(), receiver, owner, shares, duration);
    }

    /// @notice ERC4626 override
    /// @param shares amount of shares to redeem
    /// @param receiver address to receive assets
    /// @param owner address of owner
    /// @param duration duration of exit
    function redeem(uint256 shares, address receiver, address owner, uint256 duration) external {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        _exit(msg.sender, receiver, owner, shares, duration);
    }

    /// @notice cancels an existing exit
    /// @param index index of exit
    function cancelExit(uint256 index) external checkExit(msg.sender, index) {
        ExitInfo memory exit = userExits[msg.sender][index];

        exiting[msg.sender] -= exit.shares;

        // burn compensation
        _burn(msg.sender, exit.compensation);
        _unstake(exit.compensation, msg.sender);

        // mint shares back
        _mint(msg.sender, exit.shares);
        _stake(exit.shares, msg.sender);

        // remove exit from array
        _deleteExit(msg.sender, index);
    }

    /// @notice withdraw assets once an exit is over
    /// @param receiver address to receive assets
    /// @param index index of exit
    function leave(address receiver, uint256 index) external checkExit(msg.sender, index) {
        
        ExitInfo memory exit = userExits[msg.sender][index];
        if (block.timestamp <= exit.time) revert TooEarly(block.timestamp, exit.time);

        exiting[msg.sender] -= exit.shares;

        // burn msg.sender compensation
        _burn(msg.sender, exit.compensation);
        _unstake(exit.compensation, msg.sender);

        // send receiver assets and burn excess assets
        _leave(convertToAssets(exit.shares), convertToAssets(exit.exitShares), receiver);

        // remove exit from array
        _deleteExit(msg.sender, index); 
    }

    /// @notice claim multiple rewards for `msg.sender` and send them to `recipient`
    /// @param recipient address to send rewards to
    /// @param rewardTokenIndices indices of reward tokens to claim
    function getReward(address recipient, uint8[] calldata rewardTokenIndices) external {
        _getReward(msg.sender, recipient, rewardTokenIndices);
    }

    /// @notice claim rewards for `msg.sender` and send them to `recipient`
    /// @param recipient address to send rewards to
    /// @param rewardTokenIndex index of reward token to claim
    function getReward(address recipient, uint8 rewardTokenIndex) external returns (uint256) {
        return _getReward(msg.sender, recipient, rewardTokenIndex);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Override ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice ERC4626 override,
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {}

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {}

    /// @notice ERC20 override, restricted use
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {}

    /// @notice ERC20 override, restricted use
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {}

    /// @notice ERC4626 override, stakes shares into the staking contract
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        _stake(shares, receiver);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice start an exit process
    /// @param caller address of caller
    /// @param receiver address to receive assets
    /// @param owner address of owner
    /// @param shares amount of shares to exit
    /// @param duration duration of exit
    function _exit(
        address caller,
        address receiver,
        address owner,
        uint256 shares,
        uint256 duration
    ) internal virtual {
        if (duration < params.minExitDuration) revert DurationTooShort(params.minExitDuration, duration);
        if (duration > params.maxExitDuration) revert DurationTooLong(params.maxExitDuration, duration);
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        _unstake(shares, owner);

        uint256 exitShares = getExitShares(shares, duration);

        emit Exited(owner, shares, exitShares, duration);

        if (duration > 0) {
            exiting[owner] += shares;
            uint256 compensation = Math.mulDiv(exitShares, params.compensationRatio, ONE);
            if (compensation > 0) {
                _mint(owner, compensation); 
                _stake(compensation, owner);
            }
            userExits[owner].push(ExitInfo(shares, exitShares, compensation, block.timestamp + duration));
        } else {
            _leave(convertToAssets(shares), convertToAssets(exitShares), receiver);
            emit Left(owner, exitShares, shares);
        }
    }

    /// @notice withdraw assets once an exit is over and burn excess shares
    /// @param assets amount of shares to exit
    /// @param exitAssets amount of shares received for 
    /// @param recipient address to receive assets
    function _leave(uint256 assets, uint256 exitAssets, address recipient) internal {
        uint256 excess = assets - exitAssets;
        IERC20(asset()).safeTransfer(recipient, exitAssets);
        IBase(address(asset())).burn(excess);
    }

    /// @notice delete an exit entry from `owner`
    /// @param owner address of owner
    /// @param index index of exit
    function _deleteExit(address owner, uint256 index) internal {
        userExits[owner][index] = userExits[owner][userExits[owner].length - 1];
        userExits[owner].pop();
    }

    /// @notice ERC20 override, needed to get an account's voting units
    /// @param account address of account
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return stakeOf[account];
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Owner //////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice update the parameters for exiting
    /// @param _newParams new parameters
    function updateParameters(Params calldata _newParams) external onlyOwner {
        if (_newParams.minExitRatio >= _newParams.maxExitRatio) revert WrongRatio(_newParams.minExitRatio, _newParams.maxExitRatio); 
        if (_newParams.minExitDuration >= _newParams.maxExitDuration) revert WrongDuration(_newParams.minExitDuration, _newParams.maxExitDuration);

        if(_newParams.maxExitRatio != ONE || _newParams.maxExitDuration > MAX_EXIT_DURATION || _newParams.compensationRatio > ONE) revert InvalidParams();

        params = _newParams;

        emit ParametersUpdated(
            _newParams.minExitRatio, 
            _newParams.maxExitRatio, 
            _newParams.minExitDuration, 
            _newParams.maxExitDuration, 
            _newParams.compensationRatio
        );
    }
}