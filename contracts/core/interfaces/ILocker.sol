// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILocker {
    function deposit(uint256 amount, address recipient) external;
    function totalLocked() external view returns (uint256);
}