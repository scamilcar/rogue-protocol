// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract WETH is ERC20("Wrapped Ether", "WETH9") {

    mapping(address => uint256) public balance;

    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable virtual {
        balance[msg.sender] += msg.value;
    }

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256 wad) external virtual {
        require(balance[msg.sender] >= wad);
        balance[msg.sender] -= wad;
        (bool sent, ) = payable(msg.sender).call{value: wad}("");
        require(sent, "Failed to send Ether");
    }
}