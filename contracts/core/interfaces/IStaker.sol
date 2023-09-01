// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStaker {
    function stakingToken() external view returns (IERC20);
    function stake(uint256 amount, address account) external;
}