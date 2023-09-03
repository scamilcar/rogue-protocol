// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest} from "test/live/BaseTest.sol";

import "forge-std/console.sol";

// vm.expectRevert(stdError.arithmeticError)
// vm.expectRevert(contract.Error.selector)

contract BoosterWithdrawTest is BaseTest {
    function setUp() public {
        deploy();
    }

    /// @notice test deposit
    function test_withdraw(uint256 assets) public {

        // prepare
        assets = bound(assets, 1, poolPosition.balanceOf(alice));
        address recipient = alice;

        vm.startPrank(alice);

        // deposit 
        poolPosition.approve(address(booster), assets);
        booster.deposit(assets, recipient);

        // cache 
        uint256 assetBalanceBefore = poolPosition.balanceOf(recipient);

        // withdraw
        booster.withdraw(assets, recipient, alice);

        vm.stopPrank();
        
        // assertions
        assertEq(booster.stakeOf(recipient), 0, "stake of");
        assertEq(booster.totalStakes(), 0, "total stakes");

        assertEq(poolPosition.balanceOf(recipient), assetBalanceBefore + assets, "asset balance of recipient");

        assertEq(booster.balanceOf(recipient), 0, "balance of");
        assertEq(booster.totalSupply(), 0, "total supply");

        assertEq(lpReward.balanceOf(address(board)), 0, "board lpReward balance");
        assertEq(poolPosition.balanceOf(address(lpReward)), 0, "booster balance");
    }

    /// @notice test mint
    function test_redeem(uint256 shares) public {

        // prepare
        shares = bound(shares, 1, poolPosition.balanceOf(alice));
        address recipient = alice;

        // cache
        uint256 assets = booster.previewMint(shares);
        
        vm.startPrank(alice);

        // mint
        poolPosition.approve(address(booster), assets);
        booster.mint(shares, recipient);

        // cache
        uint256 assetBalanceBefore = poolPosition.balanceOf(recipient);

        // redeem
        shares = bound(shares, 1, booster.maxRedeem(recipient));
        booster.redeem(shares, recipient, alice);

        vm.stopPrank();

        // assertions
        assertEq(booster.stakeOf(recipient), 0, "stake of");
        assertEq(booster.totalStakes(), 0, "total stakes");

        assertEq(poolPosition.balanceOf(recipient), assetBalanceBefore + assets, "asset balance of recipient");

        assertEq(booster.balanceOf(recipient), 0, "balance of");
        assertEq(booster.totalSupply(), 0, "total supply");

        assertEq(lpReward.balanceOf(address(board)), 0, "board lpReward balance");
        assertEq(poolPosition.balanceOf(address(lpReward)), 0, "booster balance");
    }
}
