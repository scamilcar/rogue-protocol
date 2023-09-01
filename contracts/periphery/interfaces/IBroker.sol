// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBroker {
    function quoteTokens() external view returns (address[] memory);
    function board() external view returns (address);
    function manager() external view returns (address);
    function escrow() external view returns (address);
    function locker() external view returns (address);
    function staker() external view returns (address);
    function mav() external view returns (address);
    function claimToken() external view returns (address);
}