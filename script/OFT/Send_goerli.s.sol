// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MockLocker} from "../utils/MockLocker.sol";

contract Send_goerli is Script {

    MockLocker locker = MockLocker(0x1aC5971ef34801349c96456Cff0D09F66E1B5a31);
    
    address deployer = 0xddd7eE6F8fb5bDb3709f30C11a024A2dd60ea014;
    bytes toAddress = abi.encodePacked(deployer);
    uint16 bscChainId = 10102;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        locker.sendFrom{value: 1e16}(deployer, bscChainId, toAddress, 1e18, payable(deployer), deployer, "");

        vm.stopBroadcast();
    }
}