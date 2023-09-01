// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest} from "test/live/BaseTest.sol";

// vm.expectRevert(stdError.arithmeticError)

contract BoosterDepositTest is BaseTest {
    function setUp() public {
        deploy();
    }

    function test_deposit() public  returns(bool) {
        // assume
        // vm.assume(assets > 1e6);
        // vm.assume(assets < IERC20(poolPosition).balanceOf(alice));
        // deposit
        vm.startPrank(alice);
        IERC20(poolPosition).approve(address(booster), 1e18);
        booster.deposit(1e18, alice);
        vm.stopPrank();
    }
}
