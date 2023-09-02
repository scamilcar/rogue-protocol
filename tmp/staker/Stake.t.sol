// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract StakerStakeTest is BaseTest {
    function setUp() public {
        deploy();
    }

    // should be able to deposit MAV in locker
    function test_stake_caller(uint amount) public  {

        vm.assume(amount > 0);
        vm.assume(amount < mav.balanceOf(alice));
        vm.startPrank(alice);
        // lock
        _lock(amount, alice);
        // deposit
        IERC20(address(locker)).approve(address(staker), amount);
        staker.stake(amount, alice);
        vm.stopPrank();

        // assertions
        assertEq(staker.balanceOf(alice), amount);
        assertEq(staker.totalSupply(), amount);
        assertEq(staker.delegates(alice), alice);
    }

    function test_stakeAll() public {
        uint balance = mav.balanceOf(alice);
        vm.startPrank(alice);
        // lock
        _lock(balance, alice);
        // deposit
        IERC20(address(locker)).approve(address(staker), balance);
        staker.stakeAll(alice);
        vm.stopPrank();

        // assertions
        assertEq(staker.balanceOf(alice), balance);
        assertEq(staker.totalSupply(), balance);
        assertEq(staker.delegates(alice), alice);
        assertEq(locker.balanceOf(alice), 0);
    }

    function _lock(uint amount, address to) internal {
        mav.approve(address(locker), amount);
        locker.deposit(amount, to);
    }
}