// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";

contract BrokerDistributeTest is BaseTest {

    function setUp() public {
        deploy();
    }

    function test_distributeEmissions(uint mavAmount) public {
        // lock MAV on veMAV 
        uint amount = mav.balanceOf(address(this));
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);

        vm.assume(mavAmount > 0);
        vm.assume(mavAmount < amount);

        // impersonate an address able to mint
        vm.startPrank(address(staker));
        broker.mint(address(this), mavAmount);

        vm.stopPrank();

        // TODO assertions on rewardRate for all 3 Rewards contracts
        // uint mintedOrog = broker.mintedOrog();
        // (, uint stakerMultiplier, uint stabilityMultiplier, uint rogMultiplier) = rog.emissionParams();
        // uint one = rog.ONE_HUNDRED_PERCENT();

        // uint duration = 7 days;

        // uint stakerShare = mintedOrog * stakerMultiplier / one;
        // uint stabilityShare = mintedOrog * stabilityMultiplier / one;
        // uint rogShare = mintedOrog * rogMultiplier / one;

        // uint stakerRate = stakerShare / duration;
        // uint stabilityRate = stabilityShare / duration;
        // uint rogRate = rogShare / duration;
        
    }

    function testFail_distributeEmissions_no_mint() public {
        broker.distributeEmissions();
    }

}