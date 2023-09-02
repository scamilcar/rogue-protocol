// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";

import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";

contract MockLocker is OFT {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error NoDeposit();
    error LowBalance();
    error BoardAlreadySet();
    error BoardNotSet();
    error Disabled();
    error InvalidIncentiveValue(uint256 incentive);

    event BoardSet(address board);
    event IncentiveUpdated(uint256 incentive);
    event WithdrawalsDisabled();

    /// @notice address of MAV token
    IERC20 public immutable mav;

    /// @notice amount of MAV locked on Rogue
    uint256 public totalLocked;

    /// @notice address of the Board contract
    address public board;

    /// @notice current incentive to call lock
    uint256 public callIncentive;

    /// @notice returns true if withdrawals are enabled
    bool public enabled;

    /// @notice 100%
    uint256 public constant ONE = 1e18;

    /// @notice address of the LayerZero endpoint
    ILayerZeroEndpoint public immutable endpoint;

    /// @param _mav address of MAV contract
    /// @param _lzEndPoint address of LayerZero endpoint
    constructor(address _mav, address _lzEndPoint) OFT("Rogue MAV", "rMAV", _lzEndPoint) {
        mav = IERC20(_mav);
        endpoint = ILayerZeroEndpoint(_lzEndPoint);

        enabled = true;

        _mint(msg.sender, 1000000e18);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// User Facing ////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice deposit MAV and mint rMAV
    /// @param amount amount of MAV to lock pulled from `msg.sender`
    /// @param recipient address to mint rMAV to
    function deposit(uint256 amount, address recipient) external {
        if (amount == 0) revert ZeroAmount();
        mav.safeTransferFrom(msg.sender, address(this), amount);
        totalLocked += amount;
        _mint(recipient, amount);
    }

    /// @notice withdraw MAV and burn rMAV
    /// @param amount amount of rMAV to withdraw
    function withdraw(uint256 amount) external {
        if (!enabled) revert Disabled();
        if (amount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < amount) revert LowBalance();
        _burn(msg.sender, amount);
        totalLocked -= amount;
        mav.safeTransfer(msg.sender, amount);
    }

    /// @notice extend locks, caller get rMAV minted as incentive
    function lock() external {
        if (board == address(0)) revert BoardNotSet();
        uint256 balance = mav.balanceOf(address(this));
        if (balance == 0) revert NoDeposit();
        uint256 incentive = balance * callIncentive / ONE;
        IBoard(board).extendLockup(balance);
        _mint(msg.sender, incentive);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Owner ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice update the board address, one time call
    /// @param _board address of the new board
    function setBoard(address _board, uint256 _incentive) external onlyOwner {
        if (board != address(0)) revert BoardAlreadySet();
        if (_incentive == 0) revert InvalidIncentiveValue(_incentive);
        board = _board;
        callIncentive = _incentive;
        mav.safeApprove(_board, type(uint256).max);
        emit BoardSet(_board);
    }

    /// @notice updates the incentive rate for calling lock limiting it to 1%
    /// @param _callIncentive new incentive rate
    function updateIncentive(uint256 _callIncentive) external onlyOwner {
        if (_callIncentive == 0 || _callIncentive > 1e16) revert InvalidIncentiveValue(_callIncentive);
        callIncentive = _callIncentive;
        emit IncentiveUpdated(_callIncentive);
    }

    /// @notice disable withdrawals
    function disable() external onlyOwner {
        enabled = false;
        emit WithdrawalsDisabled();
    }
}