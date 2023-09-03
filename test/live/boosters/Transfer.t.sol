// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest} from "test/live/BaseTest.sol";

import "forge-std/console.sol";

contract BoosterTransferTest is BaseTest {
    function setUp() public {
        deploy();
    }

    /// @notice test transfer
    function test_transfer(uint256 assets, uint256 shares) public {

        // bound assets
        assets = bound(shares, 1, poolPosition.balanceOf(alice));

        // alice deposit
        _deposit(alice, alice, assets);

        // bound shares amount for transfer
        shares = bound(shares, 1, booster.balanceOf(alice));

        // cache before transfer
        uint256 balanceBeforeAlice = booster.balanceOf(alice);
        uint256 balanceBeforeBob = booster.balanceOf(bob);
        uint256 stakesBeforeAlice = booster.stakeOf(alice);
        uint256 stakesBeforeBob = booster.stakeOf(bob);
        uint256 totalSupplyBefore = booster.totalSupply();
        uint256 totalStakesBefore = booster.totalStakes();

        // transfer to bob
        vm.startPrank(alice);
        booster.transfer(bob, shares);
        vm.stopPrank();

        // cache after transfer
        uint256 balanceAfterAlice = booster.balanceOf(alice);
        uint256 balanceAfterBob = booster.balanceOf(bob);
        uint256 stakesAfterAlice = booster.stakeOf(alice);
        uint256 stakesAfterBob = booster.stakeOf(bob);
        uint256 totalSupplyAfter = booster.totalSupply();
        uint256 totalStakesAfter = booster.totalStakes();
        
        // assertions
        assertEq(balanceBeforeAlice - balanceAfterAlice, balanceAfterBob - balanceBeforeBob, "alice balance decrease by increase in bob balance");
        assertEq(stakesBeforeAlice - stakesAfterAlice, stakesAfterBob - stakesBeforeBob, "alice stake decrease by increase in bob stake");
        assertEq(totalSupplyBefore, totalSupplyAfter, "total supply");
        assertEq(totalStakesBefore, totalStakesAfter, "total stakes");
        assertEq(totalSupplyAfter, totalStakesAfter, "total supply and total stakes");
    }

    /// @notice test transferFrom
    function test_transferFrom(uint256 assets, uint256 shares) public {

        // bound assets
        assets = bound(shares, 1, poolPosition.balanceOf(alice));

        // alice deposit
        _deposit(alice, alice, assets);

        // bound shares amount for transfer
        shares = bound(shares, 1, booster.balanceOf(alice));

        // cache before transfer
        uint256 balanceBeforeAlice = booster.balanceOf(alice);
        uint256 balanceBeforeBob = booster.balanceOf(bob);
        uint256 stakesBeforeAlice = booster.stakeOf(alice);
        uint256 stakesBeforeBob = booster.stakeOf(bob);
        uint256 totalSupplyBefore = booster.totalSupply();
        uint256 totalStakesBefore = booster.totalStakes();

        // alice approves operator
        address operator = address(7373);
        vm.startPrank(alice);
        booster.approve(operator, shares);
        vm.stopPrank();

        // operator transfers from alice to bob
        vm.startPrank(operator);
        booster.transferFrom(alice, bob, shares);
        vm.stopPrank();

        // cache after transfer
        uint256 balanceAfterAlice = booster.balanceOf(alice);
        uint256 balanceAfterBob = booster.balanceOf(bob);
        uint256 stakesAfterAlice = booster.stakeOf(alice);
        uint256 stakesAfterBob = booster.stakeOf(bob);
        uint256 totalSupplyAfter = booster.totalSupply();
        uint256 totalStakesAfter = booster.totalStakes();
        
        // assertions
        assertEq(balanceBeforeAlice - balanceAfterAlice, balanceAfterBob - balanceBeforeBob, "alice balance decrease by increase in bob balance");
        assertEq(stakesBeforeAlice - stakesAfterAlice, stakesAfterBob - stakesBeforeBob, "alice stake decrease by increase in bob stake");
        assertEq(totalSupplyBefore, totalSupplyAfter, "total supply");
        assertEq(totalStakesBefore, totalStakesAfter, "total stakes");
        assertEq(totalSupplyAfter, totalStakesAfter, "total supply and total stakes");
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function _deposit(address owner, address recipient, uint amount) internal {
        vm.startPrank(owner);
        poolPosition.approve(address(booster), amount);
        booster.deposit(amount, recipient);
        vm.stopPrank();
    }
}