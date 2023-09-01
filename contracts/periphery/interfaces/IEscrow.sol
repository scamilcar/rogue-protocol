// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEscrow {
    function stake(uint256 amount, uint256 duration, address to) external;
}