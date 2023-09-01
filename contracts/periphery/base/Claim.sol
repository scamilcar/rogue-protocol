// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
@info Claim contract. It is used to account for how much ROG is claimable
*/

contract Claim is ERC20 {

    error NotBroker(address caller);

    /// @notice the address of the broker
    address public immutable broker;

    constructor() ERC20("Rogue Claim Token", "rCT") {
        broker = msg.sender;
    }

    /// @notice only orog can mint
    modifier onlyBroker() {
        if (msg.sender != broker) revert NotBroker(msg.sender);
        _;
    }

    /// @notice mint `amount` to `to`
    /// @param to address to mint to
    /// @param amount amount to mint
    function mint(address to, uint256 amount) external onlyBroker {
        _mint(to, amount);
    }

    /// @notice burn `amount` from msg.sender
    /// @param amount amount to burn
    function burn(uint256 amount) external onlyBroker {
        _burn(msg.sender, amount);
    }
}