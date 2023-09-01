// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {
    function positionBooster(address poolPosition) external view returns (address);
    function boosterPosition(address booster) external view returns (address);
    function compounder(address booster) external view returns (address);
    function isBooster(address booster) external view returns (bool);
    function rewardBooster(address booster) external view returns (address);
    function boosterInfo(address booster) external view returns (address compounder, bool mode);
}