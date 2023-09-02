// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MockLocker} from "../utils/MockLocker.sol";

contract Send_bsc is Script {

    MockLocker locker = MockLocker(0x83DC82674c083D14490d9953BB671F441a6F1bE4);
    
    address deployer = 0xddd7eE6F8fb5bDb3709f30C11a024A2dd60ea014;
    bytes toAddress = abi.encodePacked(deployer);
    uint16 goerliChainId = 10121;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        locker.sendFrom{value: 1e16}(deployer, goerliChainId, toAddress, 1e18, payable(deployer), deployer, "");

        vm.stopBroadcast();
    }
}