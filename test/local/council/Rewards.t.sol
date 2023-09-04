// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract CouncilRewardsTest is BaseTest {

    uint256 minimumRewardAmount = 100e18;
    
    function setUp() public {
        deploy();

        // add dai as reward on council
        vm.startPrank(council.owner());
        council.addNewRewardToken(address(dai), minimumRewardAmount, 7 days);
        vm.stopPrank();

        // send ROG tokens to alice
        base.transfer(alice, base.balanceOf(address(this)));
    }

    /// @notice test getReward, should get fair amount of rewards
    function test_getReward_simple(uint256 assets, uint256 notified) public {
        // bound values
        assets = bound(assets, 1, base.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to council
        dai.approve(address(council), notified);
        council.notifyAndTransfer(address(dai), notified);

        vm.startPrank(alice);

        // deposit
        base.approve(address(council), assets);
        council.deposit(assets, alice);

        // cache reward info
        IRewarder.RewardInfo[] memory info = council.rewardInfo();
        uint8 daiIndex = council.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned by alice
        uint earned = council.earned(alice, address(dai));
        uint rewardBalanceBefore = dai.balanceOf(alice);

        address recipient = alice;
        council.getReward(recipient, daiIndex);

        vm.stopPrank();

        // cache deltas
        uint acceptableDelta = notified * 1e6 / 1e18; // acceptable treshold of 10^-12 of notified amount
        uint delta = notified - earned;

        // assertions
        assertLt(delta, acceptableDelta, "precision is within acceptable delta");
        assertEq(dai.balanceOf(recipient) - rewardBalanceBefore, earned, "recipient received earned rewards");
        assertEq(council.earned(alice, address(dai)), 0, "depositor isn't eligible to rewards no more");
    }

    /// @notice test getReward, should get fair amount of rewards for more than 1 player
    function test_getReward_multi(uint256 assets, uint256 notified) public {
        // alice sents half of her LP tokens to bob
        vm.startPrank(alice);
        base.transfer(bob, base.balanceOf(alice) / 2);
        vm.stopPrank();

        // bound values
        assets = bound(assets, 1, base.balanceOf(alice));
        notified = bound(notified, minimumRewardAmount, dai.balanceOf(address(this)));

        // notify rewards to council
        dai.approve(address(council), notified);
        council.notifyAndTransfer(address(dai), notified);

        // recipients
        address recipient1 = alice;
        address recipient2 = bob;

        // players deposit
        _deposit(alice, recipient1, assets);
        _deposit(bob, recipient2, assets);

        // cache reward info
        IRewarder.RewardInfo[] memory info = council.rewardInfo();
        uint8 daiIndex = council.tokenIndex(address(dai));
        uint256 finishAt = info[daiIndex].finishAt;

        // go to finishAt to be eligible to full rewards
        vm.warp(finishAt + 1);

        // cache rewards earned and balances
        uint earnedAlice = council.earned(alice, address(dai));
        uint earnedBob = council.earned(bob, address(dai));
        uint rewardBalanceBefore1 = dai.balanceOf(recipient1);
        uint rewardBalanceBefore2 = dai.balanceOf(recipient2);

        // players get rewards
        _getReward(alice, recipient1, daiIndex);
        _getReward(bob, recipient2, daiIndex);

        // cache deltas
        uint acceptableDelta = notified * 1e6 / 1e18; // acceptable treshold of 10^-12 of notified amount
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
        base.approve(address(council), amount);
        council.deposit(amount, recipient);
        vm.stopPrank();
    }

    function _getReward(address owner, address recipient, uint8 index) internal {
        vm.startPrank(owner);
        council.getReward(recipient, index);
        vm.stopPrank();
    }
}