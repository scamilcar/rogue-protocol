// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Booster} from '../Booster.sol';
import {IBroker} from "contracts/periphery/interfaces/IBroker.sol";

contract Factory {

    /// @param _poolPosition address of the pool position contract
    /// @param _lpReward address of the lp reward contract
    /// @param _broker address of the option claim contract
    /// @param _board address of the board contract
    /// @param _name name of the vault
    /// @param _symbol symbol of the vault
    /// @return booster address of the deployed vault
    function deploy(
        address _poolPosition,
        address _lpReward,
        address _broker,
        address _board,
        string memory _name,
        string memory _symbol
    ) external returns(address booster) {
        booster = address(new Booster(
            _poolPosition,
            _lpReward,
            _broker,
            _board,
            msg.sender,
            _name,
            _symbol
        ));
    }
}