// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract StakerTransferTest is BaseTest {
    
    function setUp() public {
        deploy();
    }

    // should updateStakes and updateReward correctly
    function test_transfer_simple(uint amount) public {

        vm.assume(amount > 0);
        vm.assume(amount < mav.balanceOf(alice));

        // lock
        vm.startPrank(alice);
        _stake(amount, alice);

        // transfer
        staker.transfer(bob, amount); // transfer lp tokens to address(7)

        vm.stopPrank();
        // cache
        uint aliceBalanceAfter = IERC20(staker).balanceOf(alice);
        uint bobBalanceAfter = IERC20(staker).balanceOf(bob);

        // assertions
        assertEq(aliceBalanceAfter, 0);
        assertEq(bobBalanceAfter, amount); // check if alice has lp tokens
        assertEq(staker.totalSupply(), staker.totalStakes());
        assertEq(staker.balanceOf(alice), staker.stakeOf(alice));
    }

    // should updateStakes and updateReward correctly
    function test_transferFrom(uint amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < mav.balanceOf(alice));

        // lock
        vm.startPrank(alice);
        _stake(amount, alice);

        uint aliceBalanceBefore = IERC20(staker).balanceOf(alice);  
        uint bobBalanceBefore = IERC20(staker).balanceOf(bob);

        // approve bob 
        staker.approve(bob, amount);
        vm.stopPrank();

        // transfer
        vm.startPrank(bob);
        staker.transferFrom(alice, bob, amount); // transfer lp tokens to address(7)

        vm.stopPrank();
        // cache
        uint aliceBalanceAfter = IERC20(staker).balanceOf(alice);
        uint bobBalanceAfter = IERC20(staker).balanceOf(bob);

        // assertions
        assertEq(aliceBalanceBefore - aliceBalanceAfter, bobBalanceAfter - bobBalanceBefore);
        assertEq(aliceBalanceAfter, 0);
        assertEq(bobBalanceAfter, amount); // check if alice has lp tokens
        assertEq(staker.balanceOf(alice), staker.stakeOf(alice));
        assertEq(staker.balanceOf(bob), staker.stakeOf(bob));
        assertEq(staker.totalSupply(), staker.totalStakes());
    }

    function _stake(uint amount, address to) internal {
        mav.approve(address(locker), amount);
        locker.deposit(amount, to);
        IERC20(locker).approve(address(staker), amount);
        staker.stake(amount, to);
    }

}