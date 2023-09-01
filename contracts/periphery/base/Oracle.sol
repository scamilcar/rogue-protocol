// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Oracle {

    function price() external pure returns (uint256) {
        return 1e18;
    }
}