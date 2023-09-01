// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";
import {Oracle} from "contracts/periphery/base/Oracle.sol";

contract BrokerExerciseTest is BaseTest {

    function setUp() public {
        deploy();
    }

    function test_exercise() public {
        // setup 
        uint amount = 10e18;
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);
        address oracle = address(new Oracle());
        broker.addQuoteToken(address(dai), oracle);



        // impersonate an address able to mint
        vm.startPrank(address(staker));
        broker.mint(address(this), amount);
        vm.stopPrank();

        (uint _amount, uint _discount, uint _expiry) = broker.options(1);

        uint[] memory ids = broker.idsOfOwner(address(this));

        vm.warp(_expiry);

        uint daiBalanceBeforeExercising = dai.balanceOf(address(this));
        uint rogBalanceBeforeExercising = base.balanceOf(address(this));
        // exercise
        IERC20(address(dai)).approve(address(broker), type(uint).max);
        broker.exercise(ids[0], address(this), address(dai), false, 0); 

        assertEq(broker.balanceOf(address(this)), 0);
        assertEq(broker.totalSupply(), 0);
        assertEq(base.balanceOf(address(this)), rogBalanceBeforeExercising + _amount);
        // assertions TODO assertions the right amount of quotetoken has been pulled from the user
    }

    function testFail_exercise_after_expiry() public {
        uint amount = 10e18;
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);
        address oracle = address(new Oracle());
        broker.addQuoteToken(address(dai), oracle);



        // impersonate an address able to mint
        vm.startPrank(address(staker));
        broker.mint(address(this), amount);
        vm.stopPrank();

        (uint _amount, uint _discount, uint _expiry) = broker.options(1);

        uint[] memory ids = broker.idsOfOwner(address(this));

        vm.warp(_expiry + 1);
        IERC20(address(dai)).approve(address(broker), type(uint).max);
        broker.exercise(ids[0], address(this), address(dai), false, 0); 
    }

    function testFail_exercise_not_quote_token() public {
        uint amount = 10e18;
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);
        address oracle = address(new Oracle());
        broker.addQuoteToken(address(dai), oracle);



        // impersonate an address able to mint
        vm.startPrank(address(staker));
        broker.mint(address(this), amount);
        vm.stopPrank();

        (uint _amount, uint _discount, uint _expiry) = broker.options(1);

        uint[] memory ids = broker.idsOfOwner(address(this));

        vm.warp(_expiry);
        address quoteToken = address(mav);
        IERC20(quoteToken).approve(address(broker), type(uint).max);
        broker.exercise(ids[0], address(this), quoteToken, false, 0); 
    }

    function testFail_exercise_not_ApproveOrOwner() public {
        // setup 
        uint amount = 10e18;
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);
        address oracle = address(new Oracle());
        broker.addQuoteToken(address(dai), oracle);



        // impersonate an address able to mint
        vm.startPrank(address(staker));
        broker.mint(address(this), amount);
        vm.stopPrank();

        (uint _amount, uint _discount, uint _expiry) = broker.options(1);

        uint[] memory ids = broker.idsOfOwner(address(this));

        vm.warp(_expiry);
        // exercise
        vm.startPrank(alice);
        IERC20(address(dai)).approve(address(broker), type(uint).max);
        broker.exercise(ids[0], address(this), address(dai), false, 0);
        vm.stopPrank();
    }
}