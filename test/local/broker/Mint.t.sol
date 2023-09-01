// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "test/local/BaseTest.sol";

contract BrokerMintTest is BaseTest {

    function setUp() public {
        deploy();
    }

    function testFail_mint_notMinter() public {
        uint amount = mav.balanceOf(address(this));
        IERC20(address(mav)).approve(address(veMav), amount);
        veMav.stake(amount, 1 weeks, true);

        uint mavAmount = 1e18;
        // not minter so cannot mint
        broker.mint(address(this), mavAmount);
    }

    function test_mint_staker(uint256 mavAmount) public {

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

        (uint _amount, uint _discount, uint _expiry) = broker.options(1);

        assertEq(broker.totalSupply(), 1);
        assertEq(broker.ownerOf(1), address(this));
        assertEq(_amount, base.getMintAmount(mavAmount));
        assertEq(_expiry, block.timestamp + broker.periodDuration());
        assertEq(broker.minted(), base.getMintAmount(mavAmount));
    }
}