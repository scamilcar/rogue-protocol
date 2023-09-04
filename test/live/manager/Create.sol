// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/live/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract ManagerCreateTest is BaseTest {
    
    function setUp() public {
        deploy();
    }

    function test_create() public {
        // create booster
        booster = Booster(manager.create(address(poolPosition)));

        address claim = broker.claimToken();

        // reward info
        uint8 mavIndex = booster.tokenIndex(mav);
        uint8 claimIndex = booster.tokenIndex(claim);
        IRewarder.RewardInfo[] memory info = booster.rewardInfo();
        uint256 minMavAmount = info[mavIndex].minimumAmount;
        uint256 minClaimAmount = info[claimIndex].minimumAmount;
        (uint256 mavDuration, uint claimDuration) = (booster.rewardDuration(mav), booster.rewardDuration(claim));

        // compoud info
        (address compounder, bool compounding) = manager.boosterInfo(address(booster));

        // assertions
        assertEq(manager.rewardBooster(address(lpReward)), address(booster), "reward booster");
        assertEq(manager.positionBooster(address(poolPosition)), address(booster), "position booster");
        assertEq(compounder, manager.owner(), "compounder");
        assertFalse(compounding, "compounding");
        assertTrue(manager.isBooster(address(booster)), "is booster");
        assertTrue(booster.isApprovedRewardToken(mav), "MAV is approved reward token");
        assertTrue(booster.isApprovedRewardToken(claim), "claim is approved reward token");
        assertEq(minMavAmount, manager.baseMinRewardAmount(), "minimum mav amount");
        assertEq(minClaimAmount, manager.baseMinRewardAmount(), "minimum mav amount");
        assertEq(mavDuration, manager.baseRewardDuration(), "mav duration");
        assertEq(claimDuration, manager.baseRewardDuration(), "claim duration");
    }

    /// @notice try to create booster and fail as caller isn't owner
    function test_create_onlyOwner() public {
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.create(address(poolPosition));
        vm.stopPrank();
    }

    /// @notice try to create booster and fail as poolPosition is invalid
    function test_create_InvalidPoolPosition() public {
        address invalidPoolPosition = address(17878);
        bytes memory revertData = abi.encodeWithSelector(
            Manager.InvalidPoolPosition.selector,
            invalidPoolPosition
        );
        vm.expectRevert(revertData);
        manager.create(invalidPoolPosition);
    }

    /// @notice try to create booster and fail as booster already exists
    function test_create_BoosterExists() public {
        manager.create(address(poolPosition));
        bytes memory revertData = abi.encodeWithSelector(
            Manager.BoosterExists.selector,
            address(lpReward)
        );
        vm.expectRevert(revertData);
        manager.create(address(poolPosition));
    }
}