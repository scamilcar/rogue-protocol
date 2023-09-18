// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20,IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IReward} from "@maverick/interfaces/IReward.sol";
import {IPoolPositionSlim} from "@maverick/interfaces/IPoolPositionSlim.sol";

import {Rewarder} from "contracts/core/base/Rewarder.sol";
import {IManager} from "contracts/core/interfaces/IManager.sol";
import {IHub} from "contracts/periphery/interfaces/IHub.sol";
import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";

/*
TODO: mint oROG nft when claiming optionToken
TODO: events
*/

contract Booster is ERC4626, Rewarder {
    using SafeERC20 for IERC20;

    error EOA();

    /// @notice the address of the broker
    address public immutable broker;

    /// @notice the associated lp contract 
    address public immutable lpReward;

    /// @notice the address of the board
    address public immutable board;

    /// @param _poolPosition the associated pool position contract
    /// @param _lpReward the associated lp contract
    /// @param _broker the virtual option token distributed for liquidity mining
    /// @param _board the address of the board
    /// @param _manager the address of the owner of the booster
    /// @param name_ the name of the booster
    /// @param symbol_ the symbol of the booster
    constructor(
        address _poolPosition,
        address _lpReward,
        address _broker,
        address _board,
        address _manager,
        string memory name_,
        string memory symbol_)

        ERC4626(IERC20(_poolPosition))
        Rewarder(_manager)
        ERC20(name_, symbol_) { 

        lpReward = _lpReward;
        broker = _broker;
        board = _board;

        IERC20(_poolPosition).approve(lpReward, type(uint256).max);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// View ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice overriden ERC4626 method
    function totalAssets() public view override returns (uint256) {
        return IReward(lpReward).balanceOf(board);
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// User-facing //////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice get caller's rewards for a list of reward token index
    /// @param recipient address to receive the rewards
    /// @param rewardTokenIndices list of reward token index
    function getReward(address recipient, uint8[] calldata rewardTokenIndices) external {
        _getReward(msg.sender, recipient, rewardTokenIndices);
    }

    /// @notice get caller's rewards for a single reward token index
    /// @param recipient address to receive the rewards
    /// @param rewardTokenIndex reward token index
    /// @return reward amount
    function getReward(address recipient, uint8 rewardTokenIndex) external returns (uint256) {
        return _getReward(msg.sender, recipient, rewardTokenIndex);
    }
    
    ////////////////////////////////////////////////////////////////
    /////////////////////////// Override ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice ERC4626 modified internal function. It stakes the asset in lpReward with board as recipient
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // slither-disable-next-line reentrancy-no-eth
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        IReward(lpReward).stake(assets, board);
        _stake(shares, receiver);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /// @notice ERC4626 modified internal function. It calls the Board to unstake assets which sends them to receiver
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
        IBoard(board).unstake(lpReward, assets, receiver);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice update rewards before transfer
    /// @param from address to transfer from
    /// @param to address to transfer to
    /// @param amount amount to transfer
    /// @dev would not update rewards, stakes and  if `to` is whitelisted
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0)) {
            updateAllRewards(from);
            updateAllRewards(to);
            _updateStakes(from, to, amount);
        } 
    }

    /// @notice updates stakes
    function _updateStakes(address from, address to, uint256 amount) internal {
        stakeOf[from] -= amount;
        stakeOf[to] += amount;
    }
}