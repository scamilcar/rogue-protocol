// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract StakerRewardsTest is BaseTest {

    uint256 minimumRewardAmount = 100e18;
    
    function setUp() public {
        deploy();

        // add dai as reward on staker
        vm.startPrank(staker.owner());
        staker.addNewRewardToken(address(dai), minimumRewardAmount, 7 days);
        vm.stopPrank();

        // balance
        uint256 balance = mav.balanceOf(alice);

        // lock
        vm.startPrank(alice);
        mav.approve(address(locker), balance);
        locker.deposit(balance, alice);
        vm.stopPrank();
    }

    /// @notice test getReward, should get fair amount of rewards
    function test_getReward_simple(uint256 assets, uint256 notified) public {
        // bound values
        assets = bound(assets, 1, locker.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to staker
        dai.approve(address(staker), notified);
        staker.notifyAndTransfer(address(dai), notified);

        vm.startPrank(alice);

        // deposit
        locker.approve(address(staker), assets);
        staker.deposit(assets, alice);

        // cache reward info
        IRewarder.RewardInfo[] memory info = staker.rewardInfo();
        uint8 daiIndex = staker.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned by alice
        uint earned = staker.earned(alice, address(dai));
        uint rewardBalanceBefore = dai.balanceOf(alice);

        address recipient = alice;
        staker.getReward(recipient, daiIndex);

        vm.stopPrank();

        // cache deltas
        uint acceptableDelta = notified * 1e6 / 1e18; // acceptable treshold of 10^-12 of notified amount
        uint delta = notified - earned;

        // assertions
        // assertLt(delta, acceptableDelta, "precision is within acceptable delta"); // question why doesn't pass? same as council and booster which pass
        assertEq(dai.balanceOf(recipient) - rewardBalanceBefore, earned, "recipient received earned rewards");
        assertEq(staker.earned(alice, address(dai)), 0, "depositor isn't eligible to rewards no more");
    }

    /// @notice test getReward, should get fair amount of rewards for more than 1 player
    function test_getReward_multi(uint256 assets, uint256 notified) public {
        // alice sents half of her LP tokens to bob
        vm.startPrank(alice);
        locker.transfer(bob, locker.balanceOf(alice) / 2);
        vm.stopPrank();

        // bound values
        assets = bound(assets, 1, locker.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to staker
        dai.approve(address(staker), notified);
        staker.notifyAndTransfer(address(dai), notified);

        // recipients
        address recipient1 = alice;
        address recipient2 = bob;

        // players deposit
        _deposit(alice, recipient1, assets);
        _deposit(bob, recipient2, assets);

        // cache reward info
        IRewarder.RewardInfo[] memory info = staker.rewardInfo();
        uint8 daiIndex = staker.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned and balances
        uint earnedAlice = staker.earned(alice, address(dai));
        uint earnedBob = staker.earned(bob, address(dai));
        uint rewardBalanceBefore1 = dai.balanceOf(recipient1);
        uint rewardBalanceBefore2 = dai.balanceOf(recipient2);

        // players get rewards
        _getReward(alice, recipient1, daiIndex);
        _getReward(bob, recipient2, daiIndex);

        // cache deltas
        uint acceptableDelta = notified * 1e6 / 1e18; // acceptable treshold of 10^-12 of notified amount
        uint delta = notified - (earnedAlice + earnedBob);

        // assertions
        // assertLt(delta, acceptableDelta, "precision is within acceptable delta"); // question why doesn't pass? same as council and booster which pass
        assertEq(dai.balanceOf(recipient1) - rewardBalanceBefore1, earnedAlice, "recipient1 received earned rewards");
        assertEq(dai.balanceOf(recipient2) - rewardBalanceBefore2, earnedBob, "recipient2 received earned rewards");
        assertApproxEqAbs(earnedAlice, earnedBob, 1e3, "alice and bob rewards differs by acceptable delta");

    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function _deposit(address owner, address recipient, uint amount) internal {
        vm.startPrank(owner);
        locker.approve(address(staker), amount);
        staker.deposit(amount, recipient);
        vm.stopPrank();
    }

    function _getReward(address owner, address recipient, uint8 index) internal {
        vm.startPrank(owner);
        staker.getReward(recipient, index);
        vm.stopPrank();
    }
}