// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {Oracle} from "contracts/periphery/base/Oracle.sol";

contract BrokerQuoteTest is BaseTest {

    function setUp() public {
        deploy();
    }

    // should be able to add a quote token
    function test_addQuoteToken() public {
        address oracle = address(new Oracle());
        address quoteToken = address(dai);
        broker.addQuoteToken(quoteToken, oracle);
        assertTrue(broker.isQuoteToken(quoteToken));
        assertEq(broker.oracles(quoteToken), oracle);
    }

    // should not be able to add a quote token that already exists
    function testFail_addQuoteToken_alreadyQuoteToken() public {
        address oracle = address(new Oracle());
        address quoteToken = address(dai);
        broker.addQuoteToken(quoteToken, oracle);
        broker.addQuoteToken(quoteToken, oracle);
    }

    // should be able to remove a quote token
    function test_removeQuoteToken() public {
        address oracle = address(new Oracle());
        address quoteToken = address(dai);
        broker.addQuoteToken(quoteToken, oracle);
        broker.removeQuoteToken(quoteToken);

        assertTrue(!broker.isQuoteToken(quoteToken));
    }

    // should not be able to remove a quote token that does not exist
    function testFail_removeQuoteToken_notQuoteToken() public {
        broker.removeQuoteToken(address(dai));
    }

    // should be able to modify a quote token oracle
    function test_modifyQuoteTokenOracle() public {
        address oracle = address(new Oracle());
        address quoteToken = address(dai);
        broker.addQuoteToken(quoteToken, oracle);
        address newOracle = address(new Oracle());
        broker.modifyQuoteTokenOracle(quoteToken, newOracle);
        assertEq(broker.oracles(quoteToken), newOracle);
    }

    // should not be able to modify a quote token oracle that does not exist
    function testFail_modifyQuoteTokenOracle_notQuoteToken() public {
        address oracle = address(new Oracle());
        address quoteToken = address(dai);
        broker.modifyQuoteTokenOracle(address(mav), oracle);
    }

    // should not be able to modify a quote token oracle that does not exist
    function test_setPeriodDuration() public {
        uint256 periodDuration = 1 days;
        broker.setPeriodDuration(periodDuration);
        assertEq(broker.periodDuration(), periodDuration);
    }

    // should be able to set the discount interval
    function test_setDiscountInterval_notOwner() public {
        uint minDiscount = 1000;
        uint maxDiscount = 5000;
        broker.updateDiscountInterval(minDiscount, maxDiscount);
        (,, uint _minDiscount, uint _maxDiscount,,) = broker.params();
        assertEq(_minDiscount, minDiscount);
        assertEq(_maxDiscount, maxDiscount);
    }

    // should be able to set earnings manager
    function test_setEarningsManager() public {
        address newBoard = address(1);
        broker.setEarningsManager(newBoard);
        assertEq(broker.board(), newBoard);
    }
}