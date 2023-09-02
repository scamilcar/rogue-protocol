// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseTest} from "test/live/BaseTest.sol";

import "forge-std/console.sol";

// vm.expectRevert(stdError.arithmeticError)
// vm.expectRevert(contract.Error.selector)

contract BoosterDepositTest is BaseTest {
    function setUp() public {
        deploy();
    }

    function test_deposit(uint256 assets) public  returns(bool) {
        // bound
        assets = bound(assets, 1, IERC20(poolPosition).balanceOf(alice));

        address recipient = alice;
        
        // deposit
        vm.startPrank(alice);
        IERC20(poolPosition).approve(address(booster), assets);
        booster.deposit(assets, alice);
        vm.stopPrank();

        // assertEq()
    }
}
