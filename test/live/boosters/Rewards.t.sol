// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/live/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract BoosterRewardsTest is BaseTest {

    uint256 minimumRewardAmount = 100e18;
    
    function setUp() public {
        deploy();

        // create a booster
        booster = Booster(manager.create(address(poolPosition)));

        // add dai as reward on booster
        vm.startPrank(address(manager));
        booster.addNewRewardToken(address(dai), minimumRewardAmount, 7 days);
        vm.stopPrank();
    }

    /// @notice test getReward, should get fair amount of rewards
    function test_getReward_simple(uint256 assets, uint256 notified) public {
        // bound values
        assets = bound(assets, 1, poolPosition.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to booster
        dai.approve(address(booster), notified);
        booster.notifyAndTransfer(address(dai), notified);

        vm.startPrank(alice);

        // deposit
        poolPosition.approve(address(booster), assets);
        booster.deposit(assets, alice);

        // cache reward info
        IRewarder.RewardInfo[] memory info = booster.rewardInfo();
        uint8 daiIndex = booster.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned by alice
        uint earned = booster.earned(alice, address(dai));
        uint rewardBalanceBefore = dai.balanceOf(alice);

        address recipient = alice;
        booster.getReward(recipient, daiIndex);

        vm.stopPrank();

        // cache deltas
        uint acceptableDelta = notified * 1e6 / 1e18; // acceptable treshold of 10^-12 of notified amount
        uint delta = notified - earned;

        // assertions
        assertLt(delta, acceptableDelta, "precision is within acceptable delta");
        assertEq(dai.balanceOf(recipient) - rewardBalanceBefore, earned, "recipient received earned rewards");
        assertEq(booster.earned(alice, address(dai)), 0, "depositor isn't eligible to rewards no more");
    }

    /// @notice test getReward, should get fair amount of rewards for more than 1 player
    function test_getReward_multi(uint256 assets, uint256 notified) public {
        // alice sents half of her LP tokens to bob
        vm.startPrank(alice);
        poolPosition.transfer(bob, poolPosition.balanceOf(alice) / 2);
        vm.stopPrank();

        // bound values
        assets = bound(assets, 1, poolPosition.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to booster
        dai.approve(address(booster), notified);
        booster.notifyAndTransfer(address(dai), notified);

        // recipients
        address recipient1 = alice;
        address recipient2 = bob;

        // players deposit
        _deposit(alice, recipient1, assets);
        _deposit(bob, recipient2, assets);

        // cache reward info
        IRewarder.RewardInfo[] memory info = booster.rewardInfo();
        uint8 daiIndex = booster.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned and balances
        uint earnedAlice = booster.earned(alice, address(dai));
        uint earnedBob = booster.earned(bob, address(dai));
        uint rewardBalanceBefore1 = dai.balanceOf(recipient1);
        uint rewardBalanceBefore2 = dai.balanceOf(recipient2);

        // players get rewards
        _getReward(alice, recipient1, daiIndex);
        _getReward(bob, recipient2, daiIndex);

        // cache deltas
        uint acceptableDelta = notified * 1e10 / 1e18; // acceptable treshold of 10^-12 of notified amount
        uint delta = notified - (earnedAlice + earnedBob);

        // assertions
        assertLt(delta, acceptableDelta, "precision is within acceptable delta");
        assertEq(dai.balanceOf(recipient1) - rewardBalanceBefore1, earnedAlice, "recipient1 received earned rewards");
        assertEq(dai.balanceOf(recipient2) - rewardBalanceBefore2, earnedBob, "recipient2 received earned rewards");
        assertApproxEqAbs(earnedAlice, earnedBob, 1e3, "alice and bob rewards differs by acceptable delta");

    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function _deposit(address owner, address recipient, uint amount) internal {
        vm.startPrank(owner);
        poolPosition.approve(address(booster), amount);
        booster.deposit(amount, recipient);
        vm.stopPrank();
    }

    function _getReward(address owner, address recipient, uint8 index) internal {
        vm.startPrank(owner);
        booster.getReward(recipient, index);
        vm.stopPrank();
    }
}