// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBase {
    function getMintAmount(uint256 _amount) external view returns (uint256);
    function mint(address _to, uint256 _amount) external;
    function emissionParams() external view returns (uint, uint, uint, uint);
    function burn(uint256 _amount) external;
}