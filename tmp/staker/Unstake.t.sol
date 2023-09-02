// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract StakerUnstakerTest is BaseTest {
    
    function setUp() public {
        deploy();
    }

    function test_unstake_simple(uint amount) public {

        vm.assume(amount > 0);
        vm.assume(amount < mav.balanceOf(alice));
        vm.startPrank(alice);
        // stake 
        _stake(amount, alice);
        // cache
        uint stakesBefore = staker.balanceOf(alice);
        uint totalStakesBefore = staker.totalSupply();

        // unstake
        staker.unstake(amount, alice);
        vm.stopPrank();

        // assertions
        assertEq(staker.balanceOf(alice), stakesBefore - amount);
        assertEq(staker.totalSupply(), totalStakesBefore - amount);
    }

    function test_unstakeAll(uint amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < mav.balanceOf(alice));
        vm.startPrank(alice);

        // stake 
        _stake(amount, alice);

        uint stakesBefore = staker.balanceOf(alice);
        uint totalStakesBefore = staker.totalSupply();

        // unstake
        staker.unstake(amount, alice);
        vm.stopPrank();

        // assertions
        assertEq(staker.balanceOf(alice), stakesBefore - amount);
        assertEq(staker.totalSupply(), totalStakesBefore - amount);
        assertEq(staker.totalSupply(), 0);
    }

    function _stake(uint amount, address to) internal {
        mav.approve(address(locker), amount);
        locker.deposit(amount, to);
        IERC20(locker).approve(address(staker), amount);
        staker.stake(amount, to);
    }
}