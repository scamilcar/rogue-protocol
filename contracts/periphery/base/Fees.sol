// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVotingEscrow} from "@maverick/interfaces/IVotingEscrow.sol";
import {IPoolPositionSlim} from "@maverick/interfaces/IPoolPositionSlim.sol";
import {IPool} from "@maverick/interfaces/IPool.sol";
import {IReward} from "@maverick/interfaces/IReward.sol";

import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";
import {ILocker} from "contracts/core/interfaces/ILocker.sol";
import {IManager} from "contracts/core/interfaces/IManager.sol";
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";
import {IFees} from "contracts/periphery/interfaces/IFees.sol";


// TODO compound flag in all distribute functions

contract Fees is IFees, Ownable {
    using SafeERC20 for IERC20;

    // rogue
    address public locker;
    address public broker;
    IManager public manager;
    address public hub;
    address public staker;
    address public escrow;
    IVotingEscrow public veMav;
    address public mav;

    address public override rogueTreasury;

    // other
    address public weth;
    uint256 public collectedMav;
    Allocations public allo;

    // constant
    uint256 public constant maxDividends = 0.5e18;
    uint256 constant ONE = 1e18;
    

    mapping(address => uint256) public collectedOptionFees;

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Notify ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice should be called by broker to send quote tokens
    function notifyBrokerFees(address token, uint256 amount) external override {
        // pull tokens
        // IERC20(mav).safeTransferFrom(msg.sender, address(this), amount);
        // collectedMav += amount;
        
        // emit MAVNotified(msg.sender, amount);
        // handle accounting
        collectedOptionFees[token] += amount;
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////// Distribute ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice should distribute the collected liquidity fees to the different parties
    function distributeLiquidityFees() external {
        (uint256 rewards, uint256 dividends, uint256 treasury) = _getAllocationsAmounts(collectedMav, allo.liquidity);

        if (rewards > 0) IRewarder(staker).notifyAndTransfer(weth, rewards);
        if (dividends > 0) IRewarder(escrow).notifyAndTransfer(weth, dividends);
        if (treasury > 0) IERC20(weth).safeTransfer(rogueTreasury, treasury);
    }

    /// @notice should distribute the collected lock fees to the different parties
    function distributeLockFees(uint256 start, uint256 end) external {
        uint256 collectedEth = _convertSwapFees(start, end);
        (uint256 rewards, uint256 dividends, uint256 treasury) = _getAllocationsAmounts(collectedEth, allo.lock);

        ILocker(locker).deposit(rewards + dividends, address(this));

        if (rewards > 0) IRewarder(staker).notifyAndTransfer(locker, rewards);
        if (dividends > 0) IRewarder(escrow).notifyAndTransfer(locker, dividends);
        if (treasury > 0) IERC20(mav).safeTransfer(rogueTreasury, treasury);
    }

    /// @notice should distribute the collected option fees to the different parties
    function distributeOptionFees() external {
        address[] memory quoteTokens = IBroker(broker).quoteTokens();
        for (uint256 i = 0; i < quoteTokens.length; ++i) {
            address quoteToken = quoteTokens[i];
            uint256 collected = collectedOptionFees[quoteToken];
            collectedOptionFees[quoteToken] = 0;
            (uint256 rewards, uint256 dividends, uint256 treasury) = _getAllocationsAmounts(collected, allo.liquidity);

            if (rewards > 0) IRewarder(staker).notifyAndTransfer(quoteToken, rewards);
            if (dividends > 0) IRewarder(escrow).notifyAndTransfer(quoteToken, dividends);
            if (treasury > 0) IERC20(quoteToken).safeTransfer(rogueTreasury, treasury);
        }
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Internal //////////////////////////
    ////////////////////////////////////////////////////////////////

    function _getAllocationsAmounts(
        uint256 amount,
        Quotas memory quotas
    ) internal pure returns (uint256 rewards, uint256 dividends, uint256 treasury) {
        rewards = amount * quotas.rewardRatio / ONE;
        dividends = amount * quotas.dividendRatio / ONE;
        treasury = amount - rewards - dividends;
    }

    /// @notice should loop swap claimed tokens to ETH
    function _convertSwapFees(uint256 start, uint256 end) internal returns(uint256 eth) {
        // address[] memory boosters = IManager(manager).boosters();
        // if (end >= boosters.length) revert InvalidLength();
        // for (uint256 i = start; i < end; ++i) {
        //     address booster = boosters[i];
        //     IPoolPositionSlim poolPosition = IPoolPositionSlim(IManager(manager).boosterPostion(booster));
        //     IPool pool = poolPosition.pool();
        //     (address tokenA, address tokenB) = pool.tokens();
        //     (uint256 feeA, uint256 feeB) = IPoll(poll).claimFees(pool);
        //     if (tokenA == weth) {
        //         eth += feeA;
        //     } else {
        //         eth += _swap(tokenA, feeA);
        //     }
        //     if (tokenB == weth) {
        //         eth += feeB;
        //     } else {
        //         eth += _swap(tokenB, feeB);
        //     }
        // }
    }

    function _swap(address token, uint256 amount) internal {}

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Resticted //////////////////////////
    ////////////////////////////////////////////////////////////////

   

    function initialize(address _broker, address _hub) external onlyOwner {
        if (broker != address(0)) revert Initialized();
        broker = _broker;
        hub = _hub;
        manager = IManager(IBroker(_broker).manager());
        escrow = IBroker(_broker).escrow();
        staker = IBroker(_broker).staker();
        locker = IBroker(_broker).locker();
    } 

    /// @notice should update the fee structure
    function updateFeeStructure(Quotas calldata _liquidity, Quotas calldata _lock, Quotas calldata _option) external onlyOwner {
        if (
            _liquidity.dividendRatio > maxDividends ||
            _lock.dividendRatio > maxDividends ||
            _option.dividendRatio > maxDividends
        ) revert InvalidDividends();
        if (
            _liquidity.rewardRatio + _liquidity.dividendRatio > ONE ||
            _lock.rewardRatio + _lock.dividendRatio > ONE ||
            _option.rewardRatio + _option.dividendRatio > ONE
        ) revert AllocationsTooHigh();

        allo.liquidity = _liquidity;
        allo.lock = _lock;
        allo.option = _option;
    }

    /// @notice should update the treasury address
    function updateTreasury(address _rogueTreasury) external onlyOwner {
        rogueTreasury = _rogueTreasury;
    }
}