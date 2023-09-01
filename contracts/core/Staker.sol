// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/utils/Votes.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Rewarder} from "contracts/core/base/Rewarder.sol";

// TODO allow compounding of rewards to more rMAV in notifyAndTransfer

contract Staker is ERC4626, Rewarder, Votes {
    using SafeERC20 for IERC20;

    /// @notice address of the Broker
    address public immutable broker;

    /// @param _stakingToken address of staking token
    /// @param _owner address of owner
    constructor(IERC20 _stakingToken, address _broker, address _owner)
        ERC4626(_stakingToken)
        Rewarder(_owner)
        ERC20("rogue-MAV Stakes", "rMAV Stakes") 
        EIP712("rogue-MAV Stakes", "1") {
        
        broker = _broker;
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// User-facing //////////////////////////
    ////////////////////////////////////////////////////////////////

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
    ////////////////////////// Overrides ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice ERC4626 override, additional `_stake` action
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        _stake(shares, receiver);
        _mint(receiver, shares);
        _transferVotingUnits(address(0), receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /// @notice ERC4626 override, additional `_unstake` action
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        _unstake(shares, owner);
        _transferVotingUnits(owner, address(0), shares);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice ERC20 override, update rewards, stakes, nd voting units
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        updateAllRewards(from);
        updateAllRewards(to);
        _updateStakes(from, to, amount);
        _transferVotingUnits(from, to, amount);
    }

    /// @notice Vote override, return the amount of voting units for `account`
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return stakeOf[account];
    }
}