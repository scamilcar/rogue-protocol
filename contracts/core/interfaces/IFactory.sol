// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactory {
    function deploy(
        address _poolPosition,
        address _lpReward,
        address _broker,
        address _board,
        string memory _name,
        string memory _symbol
    ) external returns(address vault);
}