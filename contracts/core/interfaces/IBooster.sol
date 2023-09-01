// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBooster {

    function addNewRewardToken(address token, uint256 minimumAmount, uint256 duration) external;
    function removeStaleToken(address token) external;
    function updateRewardDuration(address token, uint256 duration) external;
    function isApprovedRewardToken(address token) external view returns (bool);
    function lpReward() external view returns (address);
    function totalSupply() external view returns (uint256);
    function notifyAndTransfer(address rewardToken, uint256 amount) external;

}