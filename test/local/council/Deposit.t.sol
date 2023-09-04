// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract CouncilDepositTest is BaseTest {
    
    function setUp() public {
        deploy();

        // send ROG tokens to alice
        base.transfer(alice, base.balanceOf(address(this)));
    }

    /// @notice test deposit
    function test_deposit(uint assets) public {

        // bound
        assets = bound(assets, 1, base.balanceOf(alice));
        address recipient = alice;

        // cache
        uint256 shares = council.previewDeposit(assets);
        uint256 assetBalanceBeforeRecipient = base.balanceOf(alice);
        uint256 assetBalanceBeforecouncil = base.balanceOf(address(council));

        // deposit
        vm.startPrank(alice);
        base.approve(address(council), assets);
        council.deposit(assets, recipient);
        vm.stopPrank();

        // assertions
        assertEq(council.stakeOf(recipient), shares, "stake of");
        assertEq(council.totalStakes(), shares, "total stakes");

        assertEq(base.balanceOf(alice), assetBalanceBeforeRecipient - assets, "asset balance of recipient");
        assertEq(base.balanceOf(address(council)), assetBalanceBeforecouncil + assets, "asset balance of recipient");

        assertEq(council.balanceOf(recipient), shares, "balance of");
        assertEq(council.totalSupply(), shares, "total supply");

        assertEq(council.getVotes(recipient), shares, "votes");
        assertEq(council.delegates(recipient), recipient, "delegates");
    }

    /// @notice test mint
    function test_mint(uint shares) public {
        // bound input
        shares = bound(shares, 1, council.previewDeposit(base.balanceOf(alice)));
        address recipient = alice;

        // cache
        uint256 assets = council.previewMint(shares);
        uint256 assetBalanceBefore = base.balanceOf(alice);
        uint256 assetBalanceBeforecouncil = base.balanceOf(address(council));

        // deposit
        vm.startPrank(alice);
        base.approve(address(council), assets);
        council.mint(shares, recipient);
        vm.stopPrank();

        // assertions
        assertEq(council.stakeOf(recipient), shares, "stake of");
        assertEq(council.totalStakes(), shares, "total stakes");

        assertEq(base.balanceOf(alice), assetBalanceBefore - assets, "asset balance of recipient");
        assertEq(base.balanceOf(address(council)), assetBalanceBeforecouncil + assets, "asset balance of recipient");

        assertEq(council.balanceOf(recipient), shares, "balanceOf");
        assertEq(council.totalSupply(), shares, "totalSupply");

        assertEq(council.getVotes(recipient), shares, "votes");
        assertEq(council.delegates(recipient), recipient, "delegates");
    }

}

