// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IHub {

    function compound(IERC4626 booster, uint256 amount, bytes calldata data) external;

}