// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

// TODO test voting supply when depositing (<= type(uint224).max)

contract StakerDepositTest is BaseTest {
    
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

    /// @notice test deposit
    function test_deposit(uint assets) public {

        // bound
        assets = bound(assets, 1, locker.balanceOf(alice));
        address recipient = alice;

        // cache
        uint256 shares = staker.previewDeposit(assets);
        uint256 assetBalanceBeforeRecipient = locker.balanceOf(alice);
        uint256 assetBalanceBeforeStaker = locker.balanceOf(address(staker));

        // deposit
        vm.startPrank(alice);
        locker.approve(address(staker), assets);
        staker.deposit(assets, recipient);
        vm.stopPrank();

        // assertions
        assertEq(staker.stakeOf(recipient), shares, "stake of");
        assertEq(staker.totalStakes(), shares, "total stakes");

        assertEq(locker.balanceOf(alice), assetBalanceBeforeRecipient - assets, "asset balance of recipient");
        assertEq(locker.balanceOf(address(staker)), assetBalanceBeforeStaker + assets, "asset balance of recipient");

        assertEq(staker.balanceOf(recipient), shares, "balance of");
        assertEq(staker.totalSupply(), shares, "total supply");

        assertEq(staker.getVotes(recipient), shares, "votes");
        assertEq(staker.delegates(recipient), recipient, "delegates");
    }

    /// @notice test mint
    function test_mint(uint shares) public {
        // bound input
        shares = bound(shares, 1, staker.previewDeposit(locker.balanceOf(alice)));
        address recipient = alice;

        // cache
        uint256 assets = staker.previewMint(shares);
        uint256 assetBalanceBefore = locker.balanceOf(alice);
        uint256 assetBalanceBeforeStaker = locker.balanceOf(address(staker));

        // deposit
        vm.startPrank(alice);
        locker.approve(address(staker), assets);
        staker.mint(shares, recipient);
        vm.stopPrank();

        // assertions
        assertEq(staker.stakeOf(recipient), shares, "stake of");
        assertEq(staker.totalStakes(), shares, "total stakes");

        assertEq(locker.balanceOf(alice), assetBalanceBefore - assets, "asset balance of recipient");
        assertEq(locker.balanceOf(address(staker)), assetBalanceBeforeStaker + assets, "asset balance of recipient");

        assertEq(staker.balanceOf(recipient), shares, "balanceOf");
        assertEq(staker.totalSupply(), shares, "totalSupply");

        assertEq(staker.getVotes(recipient), shares, "votes");
        assertEq(staker.delegates(recipient), recipient, "delegates");
    }

}

