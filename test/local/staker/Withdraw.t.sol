// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract StakerWithdrawTest is BaseTest {
    
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

    /// @notice test withdraw
    function test_withdraw(uint256 assets) public {

        // bound values
        assets = bound(assets, 1, locker.balanceOf(alice));

        address recipient = alice;

        vm.startPrank(alice);

        // cache
        uint256 shares = staker.previewDeposit(assets);

        // deposit 
        locker.approve(address(staker), assets);
        staker.deposit(assets, recipient);

        // cache 
        uint256 assetBalanceBefore = locker.balanceOf(recipient);
        uint256 votesBefore = staker.getVotes(alice);

        // withdraw
        staker.withdraw(assets, recipient, alice);

        vm.stopPrank();

        // cache
        uint votesAfter = staker.getVotes(alice);

        // assertions
        assertEq(staker.stakeOf(recipient), 0, "stake of");
        assertEq(staker.totalStakes(), 0, "total stakes");

        assertEq(locker.balanceOf(recipient), assetBalanceBefore + assets, "asset balance of recipient");

        assertEq(staker.balanceOf(recipient), 0, "balance of");
        assertEq(staker.totalSupply(), 0, "total supply");

        assertEq(votesAfter, votesBefore - shares,  "votes");
    }

    /// @notice test mint
    function test_redeem(uint256 shares) public {

        // bound values
        shares = bound(shares, 1, locker.balanceOf(alice));

        address recipient = alice;

        // cache
        uint256 assets = staker.previewMint(shares);
        
        vm.startPrank(alice);

        // mint
        locker.approve(address(staker), assets);
        staker.mint(shares, recipient);

        // cache
        uint256 assetBalanceBefore = locker.balanceOf(recipient);
        uint256 votesBefore = staker.getVotes(alice);

        // redeem
        shares = bound(shares, 1, staker.maxRedeem(alice));
        staker.redeem(shares, recipient, alice);

        vm.stopPrank();

        // cache
        uint256 votesAfter = staker.getVotes(alice);

        // assertions
        assertEq(staker.stakeOf(recipient), 0, "stake of");
        assertEq(staker.totalStakes(), 0, "total stakes");

        assertEq(locker.balanceOf(recipient), assetBalanceBefore + assets, "asset balance of recipient");

        assertEq(staker.balanceOf(recipient), 0, "balance of");
        assertEq(staker.totalSupply(), 0, "total supply");

        assertEq(votesAfter, votesBefore - shares,  "votes");
    }
}