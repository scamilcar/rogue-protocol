// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
// import {MockLocker} from "../utils/MockLocker.sol";

import {Locker} from "contracts/core/Locker.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract Deploy_goerli is Script {

    address mav;
    address endpoint = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        mav = address(new MockERC20("Maverick", "MAV", 18));
        new Locker(mav, endpoint);

        vm.stopBroadcast();
    }
}