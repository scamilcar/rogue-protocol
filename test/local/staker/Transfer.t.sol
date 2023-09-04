// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract StakerTransferTest is BaseTest {
    
    function setUp() public {
        deploy();

        // balance
        uint256 balance = mav.balanceOf(alice);

        // lock
        vm.startPrank(alice);
        mav.approve(address(locker), balance);
        locker.deposit(balance, alice);
        vm.stopPrank();
    }

    /// @notice test transfer
    function test_transfer(uint256 assets, uint256 shares) public {

        // bound assets
        assets = bound(shares, 1, locker.balanceOf(alice));

        // alice deposit
        _deposit(alice, alice, assets);

        // bound shares amount for transfer
        shares = bound(shares, 1, staker.balanceOf(alice));

        // cache before transfer
        uint256 balanceBeforeAlice = staker.balanceOf(alice);
        uint256 balanceBeforeBob = staker.balanceOf(bob);
        uint256 stakesBeforeAlice = staker.stakeOf(alice);
        uint256 stakesBeforeBob = staker.stakeOf(bob);
        uint256 totalSupplyBefore = staker.totalSupply();
        uint256 totalStakesBefore = staker.totalStakes();
        uint256 votesBeforeAlice = staker.getVotes(alice);
        uint256 votesBeforeBob = staker.getVotes(bob);

        // transfer to bob
        vm.startPrank(alice);
        staker.transfer(bob, shares);
        vm.stopPrank();
        
        // assertions
        assertEq(balanceBeforeAlice - staker.balanceOf(alice), staker.balanceOf(bob) - balanceBeforeBob, "alice balance decrease by increase in bob balance");
        assertEq(stakesBeforeAlice - staker.stakeOf(alice), staker.stakeOf(bob) - stakesBeforeBob, "alice stake decrease by increase in bob stake");
        assertEq(totalSupplyBefore, staker.totalSupply(), "total supply");
        assertEq(totalStakesBefore, staker.totalStakes(), "total stakes");
        assertEq(staker.totalSupply(), staker.totalStakes(), "total supply and total stakes");
        assertEq(votesBeforeAlice - staker.getVotes(alice), staker.getVotes(bob) - votesBeforeBob, "alice votes decrease by increase in bob balance");
    }

    /// @notice test transferFrom
    function test_transferFrom(uint256 assets, uint256 shares) public {

        // bound assets
        assets = bound(shares, 1, locker.balanceOf(alice));

        // alice deposit
        _deposit(alice, alice, assets);

        // bound shares amount for transfer
        shares = bound(shares, 1, staker.balanceOf(alice));

        // cache before transfer
        uint256 balanceBeforeAlice = staker.balanceOf(alice);
        uint256 balanceBeforeBob = staker.balanceOf(bob);
        uint256 stakesBeforeAlice = staker.stakeOf(alice);
        uint256 stakesBeforeBob = staker.stakeOf(bob);
        uint256 totalSupplyBefore = staker.totalSupply();
        uint256 totalStakesBefore = staker.totalStakes();
        uint256 votesBeforeAlice = staker.getVotes(alice);
        uint256 votesBeforeBob = staker.getVotes(bob);

        // alice approves operator
        address operator = address(7373);
        vm.startPrank(alice);
        staker.approve(operator, shares);
        vm.stopPrank();

        // operator transfers from alice to bob
        vm.startPrank(operator);
        staker.transferFrom(alice, bob, shares);
        vm.stopPrank();
        
        // assertions
        assertEq(balanceBeforeAlice - staker.balanceOf(alice), staker.balanceOf(bob) - balanceBeforeBob, "alice balance decrease by increase in bob balance");
        assertEq(stakesBeforeAlice - staker.stakeOf(alice), staker.stakeOf(bob) - stakesBeforeBob, "alice stake decrease by increase in bob stake");
        assertEq(totalSupplyBefore, staker.totalSupply(), "total supply");
        assertEq(totalStakesBefore, staker.totalStakes(), "total stakes");
        assertEq(staker.totalSupply(), staker.totalStakes(), "total supply and total stakes");
        assertEq(votesBeforeAlice - staker.getVotes(alice), staker.getVotes(bob) - votesBeforeBob, "alice votes decrease by increase in bob balance");
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

}