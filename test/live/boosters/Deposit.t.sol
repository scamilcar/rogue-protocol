// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest} from "test/live/BaseTest.sol";

import "forge-std/console.sol";

contract BoosterDepositTest is BaseTest {
    function setUp() public {
        deploy();
    }

    /// @notice test deposit
    function test_deposit(uint256 assets) public {

        // prepare
        assets = bound(assets, 1, poolPosition.balanceOf(alice));
        address recipient = alice;

        // cache
        uint256 shares = booster.previewDeposit(assets);
        uint256 assetBalanceBefore = poolPosition.balanceOf(alice);
        
        // deposit
        vm.startPrank(alice);
        poolPosition.approve(address(booster), assets);
        booster.deposit(assets, recipient);
        vm.stopPrank();

        // assertions
        assertEq(booster.stakeOf(recipient), shares, "stake of");
        assertEq(booster.totalStakes(), shares, "total stakes");

        assertEq(poolPosition.balanceOf(alice), assetBalanceBefore - assets, "asset balance of recipient");

        assertEq(booster.balanceOf(recipient), shares, "balance of");
        assertEq(booster.totalSupply(), shares, "total supply");

        assertEq(lpReward.balanceOf(address(board)), assets, "board lpReward balance");
        assertEq(poolPosition.balanceOf(address(lpReward)), assets, "booster asset balance");
    }

    /// @notice test mint
    function test_mint(uint256 shares) public {

        // prepare
        shares = bound(shares, 1, booster.previewDeposit(poolPosition.balanceOf(alice)));
        address recipient = alice;

        // cache
        uint256 assets = booster.previewMint(shares);
        uint256 assetBalanceBefore = poolPosition.balanceOf(alice);
        
        // deposit
        vm.startPrank(alice);
        poolPosition.approve(address(booster), assets);
        booster.mint(shares, recipient);
        vm.stopPrank();

        // assertions
        assertEq(booster.stakeOf(recipient), shares, "stake of");
        assertEq(booster.totalStakes(), shares, "total stakes");

        assertEq(poolPosition.balanceOf(alice), assetBalanceBefore - assets, "asset balance of recipient");

        assertEq(booster.balanceOf(recipient), shares, "balanceOf");
        assertEq(booster.totalSupply(), shares, "totalSupply");

        assertEq(lpReward.balanceOf(address(board)), assets, "board lpReward balance");
        assertEq(poolPosition.balanceOf(address(lpReward)), assets, "booster asset balance");
    }
}
