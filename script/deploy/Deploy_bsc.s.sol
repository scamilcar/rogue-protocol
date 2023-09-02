// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MockLocker} from "../utils/MockLocker.sol";

contract Deploy_bsc is Script {

    address mav = address(1);
    address endpoint = 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1;

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new MockLocker(mav, endpoint);

        vm.stopBroadcast();
    }

}