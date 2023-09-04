// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "test/live/BaseTest.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";

contract ManagerManageTest is BaseTest {

    function setUp() public {
        deploy();
        booster = Booster(manager.create(address(poolPosition)));
    }

    /// @notice test to remove a booster from the array
    function test_removeBooster() public {

        // remove booster
        vm.startPrank(manager.owner());
        manager.removeBooster(address(booster));
        vm.stopPrank();

        // cache
        (address compounder, bool compounded) = manager.boosterInfo(address(booster));

        // assertions
        assertFalse(manager.isBooster(address(booster)), "is booster");
        assertEq(compounder, address(0), "compounder");
        assertFalse(compounded, "compounded");
    }

    /// @notice try to remove a booster without being owner
    function test_removeBooster_notOwner() public {
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.removeBooster(address(booster));
        vm.stopPrank();
    }

    /// @notice whitelist a reward for a booster
    function test_addBoosterReward() public {
        address rewardToken = address(dai);
        uint256 minAmount = 1e18;
        uint256 duration = 7 days;

        vm.startPrank(manager.owner());
        // add reward
        manager.addBoosterReward(address(booster), rewardToken, minAmount, duration);
        vm.stopPrank();

        // cache
        IRewarder.RewardInfo[] memory info = booster.rewardInfo();
        uint8 index = booster.tokenIndex(rewardToken);
        uint256 minAmount_ = info[index].minimumAmount;
        uint256 duration_ = booster.rewardDuration(rewardToken);

        // assertions
        assertTrue(booster.isApprovedRewardToken(rewardToken));
        assertEq(minAmount_, minAmount, "minimum amount");
        assertEq(duration_, duration, "duration");
    }

    /// @notice try to add a booster reward without being owner
    function test_addBoosterReward_notOwner() public {
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.addBoosterReward(address(booster), address(dai), 1e18, 7 days);
        vm.stopPrank();
    }

    /// @notice remove whitelisted reward for a booster
    function test_removeBoosterReward() public {
        uint256 minAmount = 1e18;
        uint256 duration = 7 days;
        address rewardToken = address(dai);
        vm.startPrank(manager.owner());
        // add reward
        manager.addBoosterReward(address(booster), rewardToken, minAmount, duration);
        // remove reward
        manager.removeBoosterReward(address(booster), rewardToken);
        vm.stopPrank();

        // assertions
        assertFalse(booster.isApprovedRewardToken(rewardToken), "is approved reward token");
        assertEq(booster.tokenIndex(rewardToken), 0, "token index");
    }

    /// @notice try to remove a booster reward without being owner
    function test_removeBoosterReward_notOwner() public {
        vm.startPrank(manager.owner());
        manager.addBoosterReward(address(booster), address(dai), 1e18, 7 days);
        vm.stopPrank();
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.removeBoosterReward(address(booster), address(dai));
        vm.stopPrank();
    }

    /// @notice update the duration of a whitelisted reward for a booster
    function test_updateBoosterRewardDuration() public {
        uint256 minAmount = 1e18;
        uint256 duration = 7 days;
        address rewardToken = address(dai);
        uint256 newDuration = 14 days;
        vm.startPrank(manager.owner());
        // add reward
        manager.addBoosterReward(address(booster), rewardToken, minAmount, duration);
        // update duration
        manager.updateBoosterRewardDuration(address(booster), rewardToken, newDuration);
        vm.stopPrank();

        // assertions
        assertEq(booster.rewardDuration(rewardToken), newDuration, "reward duration");
    }

    /// @notice try to update a booster reward duration without being owner
    function test_updateBoosterRewardDuration_notOwner() public {
        vm.startPrank(manager.owner());
        manager.addBoosterReward(address(booster), address(dai), 1e18, 7 days);
        vm.stopPrank();
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.updateBoosterRewardDuration(address(booster), address(dai), 14 days);
        vm.stopPrank();
    }

    /// @notice update the compounder of a booster
    function test_updateBoosterCompounder() public {
        address compounder = address(17878);
        vm.startPrank(manager.owner());
        manager.updateBoosterCompounder(address(booster), compounder);
        vm.stopPrank();

        // cache
        (address compounder_,) = manager.boosterInfo(address(booster));

        // assertions
        assertEq(compounder_, compounder, "compounder");
    }

    /// @notice try to update a booster compounder without being owner
    function test_updateBoosterCompounder_notOwner() public {
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.updateBoosterCompounder(address(booster), address(17878));
        vm.stopPrank();
    }

    /// @notice switch the mode of a booster, true = compounding, false = claiming
    function test_switchBoosterMode() public {

        // cache
        (, bool oldMode) = manager.boosterInfo(address(booster));

        vm.startPrank(manager.owner());
        manager.switchBoosterMode(address(booster), !oldMode);
        vm.stopPrank();

        // cache
        (, bool newMode) = manager.boosterInfo(address(booster));

        // assertions
        assertEq(newMode, !oldMode, "compounding");
    }

    /// @notice try to switch a booster mode without being owner
    function test_switchBoosterMode_notCompounder() public {
        address invalidCompounder = address(17878);
        vm.startPrank(invalidCompounder);
        vm.expectRevert(Manager.InvalidCompounder.selector);
        manager.switchBoosterMode(address(booster), true);
        vm.stopPrank();
    }

    /// @notice update base min amount and base duration
    function test_updateBaseRewardParams() public {
        uint256 minAmount = 1e18;
        uint256 duration = 7 days;
        vm.startPrank(manager.owner());
        manager.updateBaseRewardParams(minAmount, duration);
        vm.stopPrank();

        // assertions
        assertEq(manager.baseMinRewardAmount(), minAmount, "base min amount");
        assertEq(manager.baseRewardDuration(), duration, "base duration");
    }

    /// @notice try to update base reward params without being owner
    function test_updateBaseRewardParams_notOwner() public {
        address invalidOwner = address(17878);
        vm.startPrank(invalidOwner);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.updateBaseRewardParams(1e18, 7 days);
        vm.stopPrank();
    }
}