// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";
import {Oracle} from "contracts/periphery/base/Oracle.sol"; 

contract BrokerDiscountTest is BaseTest {

    uint256 public constant maxStakeDuration = 4 * (365 days);
    uint256 ONE = 1e18;
    address oracle = address(new Oracle());

    function setUp() public {
        deploy();

        // set period until expiry
        broker.setPeriodDuration(1 days);

        // add DAI as quote token
        broker.addQuoteToken(address(dai), oracle);
    }

    function test_discount_manual(uint _discount, uint _mintAmount) public {
        uint maxSupply = base.MAX_SUPPLY();
        vm.assume(_discount >= 0.01e18);
        vm.assume(_discount <= 0.99e18);
        vm.assume(_mintAmount > 0);
        vm.assume(_mintAmount < maxSupply);

        // set manual discount
        broker.setDiscountMode(true, false);
        broker.updateManualDiscounts(_discount, 0);

        // mint option
        vm.startPrank(address(staker));
        broker.mint(alice, _mintAmount);
        vm.stopPrank();
        
        uint lockDiscount = broker.getLockupDiscount();
        (uint amount, uint discount, uint expiry) = broker.options(1);
        uint quoteTokenAmount = broker.getQuoteTokenAmount(address(dai), amount, discount);
        uint quoteTokenBalanceBefore = dai.balanceOf(alice);

        // recompute expected quote token amount
        uint price = broker.getPrice(address(dai));
        uint discountedPrice = price * (ONE - discount) / ONE;
        uint expectedQuoteTokenAmount = amount * discountedPrice / ONE;

        vm.startPrank(alice);
        dai.approve(address(broker), quoteTokenAmount);
        broker.exercise(1, alice, address(dai), false, 0);
        vm.stopPrank();

        uint quoteTokenBalanceAfter = dai.balanceOf(alice);
        uint balanceDelta = quoteTokenBalanceBefore - quoteTokenBalanceAfter;

        assertEq(quoteTokenAmount, balanceDelta);
        assertEq(quoteTokenAmount, expectedQuoteTokenAmount);
        assertEq(base.balanceOf(alice), amount);
        assertEq(dai.balanceOf(address(broker)), quoteTokenAmount);
    }

    // should 
    function test_discount_activity(
        uint _mintAmount,
        uint _veMavAmount,
        uint _lockAmount
    ) public {

        uint maxSupply = base.MAX_SUPPLY();
        uint maxMavAmount = mav.balanceOf(address(this)) / 2;
        vm.assume(_mintAmount > 0);
        vm.assume(_mintAmount < maxSupply);
        vm.assume(_veMavAmount > 0);
        vm.assume(_veMavAmount < maxMavAmount);
        vm.assume(_lockAmount > 0);
        vm.assume(_lockAmount < _veMavAmount);

        // activiy simulation
        // stake on veMAV
        mav.approve(address(veMav), _veMavAmount);
        veMav.stake(_veMavAmount, maxStakeDuration, true);
        // deposit on locker
        mav.approve(address(locker), _lockAmount); // put in test fn
        locker.deposit(_lockAmount, address(this));

        uint minDiscount = 0.01e18;
        uint maxDiscount = 0.99e18;

        // set activity discount
        broker.setDiscountMode(false, false);
        broker.updateDiscountInterval(minDiscount, maxDiscount);

        // mint option
        vm.startPrank(address(staker));
        broker.mint(alice, _mintAmount);
        vm.stopPrank();

        uint lockDiscount = broker.getLockupDiscount();
        (uint amount, uint discount, uint expiry) = broker.options(1);
        uint quoteTokenAmount = broker.getQuoteTokenAmount(address(dai), amount, discount);

        uint price = broker.getPrice(address(dai));
        uint discountedPrice = price * (ONE - discount) / ONE;
        uint expectedQuoteTokenAmount = amount * discountedPrice / ONE;

        uint quoteTokenBalanceBefore = dai.balanceOf(alice);

        vm.startPrank(alice);
        dai.approve(address(broker), quoteTokenAmount);
        broker.exercise(1, alice, address(dai), false, 0);
        vm.stopPrank();

        uint quoteTokenBalanceAfter = dai.balanceOf(alice);

        uint balanceDelta = quoteTokenBalanceBefore - quoteTokenBalanceAfter;

        assertGe(discount, minDiscount);
        assertLe(discount, maxDiscount);
        assertEq(quoteTokenAmount, balanceDelta);
        assertEq(quoteTokenAmount, expectedQuoteTokenAmount);
        assertEq(base.balanceOf(alice), amount);
        assertEq(dai.balanceOf(address(broker)), quoteTokenAmount);
    }

    function test_setDiscountMode(bool _manualLockup, bool _manualLp) public {
        broker.setDiscountMode(_manualLockup, _manualLp);
        (bool manualLockup, bool manualLp,,,,) = broker.params();
        assertEq(manualLockup, _manualLockup);
        assertEq(manualLp, _manualLp);
    }

    function test_updateDiscountInterval() public {
        uint minDiscount = 0.02e18;
        uint maxDiscount = 0.1e18;
        broker.updateDiscountInterval(minDiscount, maxDiscount);
        (,, uint minActivityDiscount, uint maxActivityDiscount,,) = broker.params();
        assertEq(minActivityDiscount, minDiscount);
        assertEq(maxActivityDiscount, maxDiscount);
    }

    function testFail_updateDiscountInterval_invalid_values() public {
        uint minDiscount = 0.02e18;
        uint maxDiscount = 0.01e18;
        broker.updateDiscountInterval(minDiscount, maxDiscount);
    }
    
    function testFail_updateDiscountInterval_too_high() public {
        uint minDiscount = 0.01e18;
        uint maxDiscount = 1.01e18;
        broker.updateDiscountInterval(minDiscount, maxDiscount);
    }

    function testFail_updateManualDiscount_too_high() public {
        uint discount = 1.01e18;
        broker.updateManualDiscounts(discount, 0);
    }
}