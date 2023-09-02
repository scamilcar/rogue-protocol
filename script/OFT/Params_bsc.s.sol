// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MockLocker} from "../utils/MockLocker.sol";

contract Params_bsc is Script {

    MockLocker public lockerGoerli = MockLocker(0x1aC5971ef34801349c96456Cff0D09F66E1B5a31);
    MockLocker public lockerBsc = MockLocker(0x83DC82674c083D14490d9953BB671F441a6F1bE4);

    uint16 public goerliChainId = 10121;  
    uint16 public bscTestnetChainId = 10102;

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // concat remote addy with local addy
        bytes memory _path = abi.encodePacked(address(lockerGoerli), address(lockerBsc));
        // set trusted params
        lockerBsc.setTrustedRemote(goerliChainId, _path);
        // set min gas for bsc testnet
        lockerBsc.setMinDstGas(goerliChainId, uint16(0), uint(100000));

        vm.stopBroadcast();
    }
}
