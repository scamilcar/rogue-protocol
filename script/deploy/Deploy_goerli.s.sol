// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MockLocker} from "../utils/MockLocker.sol";

contract Deploy_goerli is Script {

    address mav = address(1);
    address endpoint = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new MockLocker(mav, endpoint);

        vm.stopBroadcast();
    }

}