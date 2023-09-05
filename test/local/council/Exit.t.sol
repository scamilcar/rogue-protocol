// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {ICouncil} from "contracts/periphery/interfaces/ICouncil.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CouncilExitTest is BaseTest {

    uint256 ONE = 1e18;
    
    function setUp() public {
        deploy();

        // send ROG tokens to alice
        base.transfer(alice, base.balanceOf(address(this)));

        // set council params
        vm.startPrank(council.owner());
        council.updateParameters(
            ICouncil.Params({
                minExitDuration: 0, 
                maxExitDuration: 7 days,
                minExitRatio: 0.5e18,
                maxExitRatio: 1e18,
                compensationRatio: 0.5e18
            })
        );
        vm.stopPrank();
    }

    /// @notice test withdraw later
    function test_withdraw_later(uint256 assets, uint256 duration) public {

        (, uint256 maxDuration,,, uint256 compensationRatio) = council.params();

        // bound values
        assets = bound(assets, 10, base.balanceOf(alice)); // quesiton safe?
        duration = bound(duration, 1, maxDuration);

        address recipient = alice;

        vm.startPrank(alice);

        // cache
        uint256 shares = council.previewDeposit(assets);

        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // withdraw
        council.withdraw(assets, recipient, alice, duration);

        uint256 _compensation = Math.mulDiv(council.getExitShares(shares, duration), compensationRatio, ONE);
        vm.stopPrank();


        (uint shares_, uint exitShares_,,, uint256 compensation_, uint256 release_) = council.userExits(alice, 0);

        // assertions
        assertEq(council.balanceOf(alice), 0, "balance of");
        assertEq(council.stakeOf(alice), _compensation, "balance of");
        assertEq(council.getVotes(alice), _compensation, "balance of");

        assertEq(council.totalSupply(), exitShares_, "total supply");
        assertEq(council.totalStakes(), _compensation, "total stakes");

        assertEq(council.delegates(alice), alice, "delegates");

        assertEq(compensation_, _compensation, "compensation");
        assertEq(release_, block.timestamp + duration, "release");
        assertEq(exitShares_, council.getExitShares(shares, duration), "exit shares");
    }

    /// @notice test withdraw now
    function test_withdraw_now(uint256 assets) public {

        // bound values
        assets = bound(assets, 1, base.balanceOf(alice));

        address recipient = alice;

        // cache
        uint256 shares = council.previewDeposit(assets);
        uint256 exitShares = council.getExitShares(shares, 0);
        uint256 expectedAssets = council.convertToAssets(exitShares);
        uint256 excessAssets = assets - expectedAssets;

        vm.startPrank(alice);
        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // cache
        uint256 balanceBefore = base.balanceOf(recipient);
        uint256 councilBalanceBefore = base.balanceOf(address(council));
        uint256 baseSupplyBefore = base.totalSupply();

        // withdraw
        council.withdraw(assets, recipient, alice, 0);

        vm.stopPrank();

        // assertions
        assertEq(council.balanceOf(alice), 0, "balance of");
        assertEq(council.stakeOf(alice), 0, "balance of");
        assertEq(council.getVotes(alice), 0, "balance of");

        assertEq(council.totalSupply(), 0, "total supply");
        assertEq(council.totalStakes(), 0, "total stakes");

        assertEq(balanceBefore + expectedAssets, base.balanceOf(recipient), "assets wtihdrawn");
        assertEq(councilBalanceBefore - excessAssets - expectedAssets, base.balanceOf(address(council)), "council looses sent and burned balance");

        assertEq(base.totalSupply(), baseSupplyBefore - excessAssets, "base supply");
    }

    /// @notice test redeem later
    function test_redeem_later(uint256 shares, uint256 duration) public {

        (, uint256 maxDuration,,, uint256 compensationRatio) = council.params();

        // bound values
        shares = bound(shares, 10, base.balanceOf(alice)); // question safe?
        duration = bound(duration, 1, maxDuration);

        address recipient = alice;

        vm.startPrank(alice);

        // cache
        uint256 assets = council.previewMint(shares);

        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // withdraw
        shares = bound(shares, 1, council.maxRedeem(alice));
        council.redeem(shares, recipient, alice, duration);

        vm.stopPrank();

        uint256 _compensation = Math.mulDiv(council.getExitShares(shares, duration), compensationRatio, ONE);

        (uint shares_, uint exitShares_,,, uint256 compensation_, uint256 release_) = council.userExits(alice, 0);

        // assertions
        assertEq(council.balanceOf(alice), 0, "balance of");
        assertEq(council.stakeOf(alice), _compensation, "balance of");
        assertEq(council.getVotes(alice), _compensation, "balance of");

        assertEq(council.totalSupply(), exitShares_, "total supply");
        assertEq(council.totalStakes(), _compensation, "total stakes");

        assertEq(council.delegates(alice), alice, "delegates");

        assertEq(compensation_, _compensation, "compensation");
        assertEq(release_, block.timestamp + duration, "release");
        assertEq(exitShares_, council.getExitShares(shares, duration), "exit shares");
    }

    /// @notice test redeem now
    function test_redeem_now(uint256 shares) public {

        // prepare
        shares = bound(shares, 1, base.balanceOf(alice));
        address recipient = alice;

        // cache
        uint256 assets = council.previewMint(shares);
        uint256 exitShares = council.getExitShares(shares, 0);
        uint256 expectedAssets = council.convertToAssets(exitShares);
        uint256 excessAssets = assets - expectedAssets;
        
        vm.startPrank(alice);

        // mint
        base.approve(address(council), assets);
        council.mint(shares, recipient);

        // cache
        uint256 balanceBefore = base.balanceOf(recipient);
        uint256 votesBefore = council.getVotes(alice);
        uint256 councilBalanceBefore = base.balanceOf(address(council));
        uint256 baseSupplyBefore = base.totalSupply();

        // redeem
        shares = bound(shares, 1, council.maxRedeem(recipient));
        council.redeem(shares, recipient, alice, 0);

        vm.stopPrank();

        // assertions
        assertEq(council.balanceOf(alice), 0, "balance of");
        assertEq(council.stakeOf(alice), 0, "balance of");
        assertEq(council.getVotes(alice), 0, "balance of");

        assertEq(council.totalSupply(), 0, "total supply");
        assertEq(council.totalStakes(), 0, "total stakes");

        assertEq(balanceBefore + expectedAssets, base.balanceOf(recipient), "assets wtihdrawn");
        assertEq(councilBalanceBefore - excessAssets - expectedAssets, base.balanceOf(address(council)), "council looses sent and burned balance");

        assertEq(base.totalSupply(), baseSupplyBefore - excessAssets, "base supply");
    }

    /// @notice try to withdraw with the ERC4626 function signature and fail 
    function test_withdraw_wrong_signature(uint256 assets) public {

        // bound values
        assets = bound(assets, 1, base.balanceOf(alice));

        address recipient = alice;

        vm.startPrank(alice);

        // cache
        uint256 shares = council.previewDeposit(assets);

        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // withdraw 
        vm.expectRevert(ICouncil.Overriden.selector);
        council.withdraw(assets, recipient, alice);

        vm.stopPrank();
    }

    /// @notice try to redeem with the ERC4626 function signature and fail 
    function test_redeem_wrong_signature(uint256 shares) public {

        // bound values
        shares = bound(shares, 1, base.balanceOf(alice));
        address recipient = alice;
        vm.startPrank(alice);

        // cache
        uint256 assets = council.previewMint(shares);

        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // withdraw
        shares = bound(shares, 1, council.maxRedeem(alice));

        // revert
        vm.expectRevert(ICouncil.Overriden.selector);
        council.redeem(shares, recipient, alice);

        vm.stopPrank();
    }

    /// @notice test leave
    function test_leave(uint256 assets, uint256 duration) public {

        (, uint256 maxDuration,,, uint256 compensationRatio) = council.params();

        // bound values
        assets = bound(assets, 1e6, base.balanceOf(alice));
        duration = bound(duration, 1, maxDuration);

        address recipient = alice;
        // cache
        uint256 shares = council.previewDeposit(assets);
        uint256 exitShares = council.getExitShares(shares, 0);
        uint256 expectedAssets = council.convertToAssets(exitShares);
        uint256 excessAssets = assets - expectedAssets;

        vm.startPrank(alice);

        // deposit 
        base.approve(address(council), assets);
        council.deposit(assets, recipient);

        // cache
        uint256 balanceBefore = base.balanceOf(recipient);
        uint256 councilBalanceBefore = base.balanceOf(address(council));
        uint256 baseSupplyBefore = base.totalSupply();

        // withdraw
        council.withdraw(assets, recipient, alice, duration);

        (uint shares_, uint exitShares_,,, uint256 compensation_, uint256 release_) = council.userExits(alice, 0);

        // go to release + 1 sec
        vm.warp(release_ + 1);

        // leave
        council.leave(alice, 0);

        // assertions
        // assertEq(council.balanceOf(alice), 0, "balance of");
        // assertEq(council.stakeOf(alice), 0, "stake of");
        // assertEq(council.getVotes(alice), 0, "balance of");

        // assertEq(council.totalSupply(), 0, "total supply");
        // assertEq(council.totalStakes(), 0, "total stakes");

        // assertEq(balanceBefore + expectedAssets, base.balanceOf(recipient), "assets withdrawn");
        // assertEq(councilBalanceBefore - excessAssets - expectedAssets, base.balanceOf(address(council)), "council looses sent and burned balance");

        // assertEq(base.totalSupply(), baseSupplyBefore - excessAssets, "base supply");
    }
}