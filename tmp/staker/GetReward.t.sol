// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.8.0;

// import "test/local/BaseTest.sol";
// import "contracts/core/interfaces/IRewarder.sol";

// uint256 constant minimumRewardAmount = 100e18;
// uint256 constant rewardDuration = 1 days;

// contract StakerGetRewardTest is BaseTest {
//     function setUp() public {
//         deploy();
//     }

//     // should get the correct rewards for a single user
//     function test_getReward_simple(uint notified) public {
//         // assume
//         vm.assume(notified > minimumRewardAmount);
//         vm.assume(notified < dai.balanceOf(address(this)));

//         // notify rewards
//         _notifyRewards(address(dai), minimumRewardAmount, rewardDuration, notified);
//         // stake
//         _stake(mav.balanceOf(address(this)), address(this));
        
//         // go to period finish
//         uint8 daiIndex = staker.tokenIndex(address(dai));
//         IRewarder.RewardInfo[] memory info = staker.rewardInfo();
//         uint256 finishAt = info[daiIndex].finishAt;
//         vm.warp(finishAt + 1);

//         // see earned
//         uint daiEarned = staker.earned(address(this), address(dai));
        
//         // cache balance before claim
//         uint daiBalanceBefore = IERC20(address(dai)).balanceOf(address(this));
//         // get reward
//         staker.getReward(address(this), daiIndex);

//         // cache balance after claim
//         uint daiBalanceAfter = IERC20(address(dai)).balanceOf(address(this));

//         // cache deltas
//         uint acceptableDelta = notified * 1e6 / 1e18; // treshold of 10^-12 of notified amount
//         uint delta = notified - daiEarned;

//         emit log_named_uint("NOTIFIED           ", notified);
//         emit log_named_uint("EARNED             ", daiEarned);
//         emit log_named_uint("DELTA              ", delta);
//         emit log_named_uint("ACCEPTABLE DELTA   ", acceptableDelta);

//         // assertions
//         // assertLe(delta, acceptableDelta);
//         assertEq(daiBalanceAfter - daiBalanceBefore, daiEarned);
//     }

//     // should get the correct rewards for multiple users
//     function test_getReward_multiplayer(uint notified) public {

//         // assume
//         vm.assume(notified > minimumRewardAmount);
//         vm.assume(notified < dai.balanceOf(address(this)));

//         // notify reward amount of DAI
//         _notifyRewards(address(dai), minimumRewardAmount, rewardDuration, notified);

//         // stake
//         uint256 aliceAmount = mav.balanceOf(address(this)) / 2;
//         uint256 bobAmount = mav.balanceOf(address(this)) - aliceAmount;
//         _stakeFor(aliceAmount, alice);
//         _stakeFor(bobAmount, bob);

//         // go to period finish
//         uint8 daiIndex = staker.tokenIndex(address(dai));
//         IRewarder.RewardInfo[] memory info = staker.rewardInfo();
//         uint256 finishAt = info[daiIndex].finishAt;
//         vm.warp(finishAt + 1);

//         // see earned
//         uint daiEarnedAlice = staker.earned(alice, address(dai));
//         uint daiEarnedBob = staker.earned(bob, address(dai));
//         emit log_named_uint("daiEarnedAlice", daiEarnedAlice);
//         emit log_named_uint("daiEarnedBob", daiEarnedBob);

//         // cache balance before claim
//         uint daiBalanceBeforeAlice = IERC20(address(dai)).balanceOf(alice);
//         uint daiBalanceBeforeBob = IERC20(address(dai)).balanceOf(bob);
        
//         // alice and bob get reward
//         vm.startPrank(alice);
//         staker.getReward(alice, daiIndex);
//         vm.stopPrank();
//         vm.startPrank(bob);
//         staker.getReward(bob, daiIndex);
//         vm.stopPrank();

//         // cache balance after claim
//         uint daiBalanceAfterAlice = IERC20(address(dai)).balanceOf(alice);
//         uint daiBalanceAfterBob = IERC20(address(dai)).balanceOf(bob);

//         // cache deltas
//         uint acceptableDelta = notified * 1e15 / 1e18; // treshold of 10^-10 of notified amount
//         uint totalEarned = daiEarnedAlice + daiEarnedBob;
//         uint delta = notified - totalEarned;

//         // assertions
//         // assertLe(delta, acceptableDelta);
//         assertApproxEqAbs(daiEarnedAlice, daiEarnedBob, 1e4); // check earnings are approx equal with 1e4 precision
//         assertEq(daiBalanceAfterAlice - daiBalanceBeforeAlice, daiEarnedAlice);
//         assertEq(daiBalanceAfterBob - daiBalanceBeforeBob, daiEarnedBob);
//     }


//     // deposit in locker and stake
//     function _stake(uint amount, address to) internal {
//         mav.approve(address(locker), amount);
//         locker.deposit(amount, to);
//         IERC20(locker).approve(address(staker), amount);
//         staker.stake(amount, to);
//     }

//     function _stakeFor(uint amount, address to) internal {
//         mav.approve(address(locker), amount);
//         locker.deposit(amount, address(this));
//         IERC20(locker).approve(address(staker), amount);
//         staker.stake(amount, to);
//     }

//     // sends rewards to staker
//     function _notifyRewards(address token, uint minRewardAmount, uint256 duration, uint notified) internal {
//         staker.addNewRewardToken(token, minimumRewardAmount, rewardDuration);
//         // notify reward amount of DAI
//         IERC20(token).approve(address(staker), notified);
//         staker.notifyAndTransfer(token, notified);
//     }
// }