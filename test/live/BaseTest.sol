// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPoolPositionManager} from "@maverick/interfaces/IPoolPositionManager.sol";
import {PoolPositionBaseSlim} from "@maverick/PoolPositionBaseSlim.sol";
import {RewardBase} from "@maverick/RewardBase.sol";
import {IVotingEscrow} from "@maverick/interfaces/IVotingEscrow.sol";

import {Manager} from "contracts/core/manager/Manager.sol";
import {Board} from "contracts/periphery/Board.sol";
import {Locker} from "contracts/core/Locker.sol";
import {Broker} from "contracts/periphery/Broker.sol";
import {Booster} from "contracts/core/Booster.sol";
import {Staker} from "contracts/core/Staker.sol";
import {Factory} from "contracts/core/manager/Factory.sol";
import {Council} from "contracts/periphery/Council.sol";
import {Hub} from "contracts/periphery/Hub.sol";

import {IWETH9} from "contracts/periphery/base/utils/PeripheryPayments.sol";

// vm.expectRevert(stdError.arithmeticError)
// vm.expectRevert(contract.Error.selector)

contract BaseTest is Test {
    using SafeERC20 for IERC20;

    // rogue state
    Manager manager;
    Locker locker;
    Broker broker;
    Booster booster;
    Staker staker;
    Factory factory;
    Board board;
    Hub hub;
    Council council;
    address base = address(1);

    uint periodDuration = 7 days;
    address owner = address(this);
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


    // maverick state
    address poolPositionManager = 0xE7583AF5121a8f583EFD82767CcCfEB71069D93A;
    address poolPositionFactory = 0x4F24D73773fCcE560f4fD641125c23A2B93Fcb05;
    address poolPositionFactoryOwner = 0xEc219699D2FAEB3F416C116dE60Cdb4AAF2f8D7c;
    address mav = 0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD;
    address endpoint = address(1);
    address poll = address(1);
    address veMav = address(1);
    address router = address(1);




    // variable state
    PoolPositionBaseSlim poolPosition = PoolPositionBaseSlim(0xc7096D9FCDE2128D1576d03aFEb6e21F34162987); // GRAI/rETH boosted position
    RewardBase lpReward = RewardBase(0x7B04F050Be9D16386c88dc7315c6486aF52b926b); // lp reward
    address rewardToken1 = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D; // rewarded token in the lpReward
    address tokenA = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0; // tokenA
    address tokenB = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E; // tokenB
    address tokenAWhale = 0x66017D22b0f8556afDd19FC67041899Eb65a21bb; // tokenAWhale
    address tokenBWhale = 0xA920De414eA4Ab66b97dA1bFE9e6EcA7d4219635; // tokenBWhale
    address lpTokensWhale = 0x7B04F050Be9D16386c88dc7315c6486aF52b926b;
    address daiWhale = 0x60FaAe176336dAb62e284Fe19B885B095d29fB7F;

    // test state
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address alice = address(1);
    address bob = address(2);

//     ////////////////////////////////////////////////////////////////
//     /////////////////////////// Setup ////////////////////////////
//     ////////////////////////////////////////////////////////////////

    function deploy() public {
        locker = new Locker(mav, endpoint);
        broker = new Broker(veMav, mav, periodDuration);
        staker = new Staker(IERC20(address(locker)), address(broker), owner);
        factory = new Factory();
        council = new Council(IERC20(base), address(broker), owner);
        board = new Board(address(mav), address(veMav), poll);
        manager = new Manager(address(factory), address(poolPositionFactory), address(broker), address(board));
        hub = new Hub(
            IWETH9(address(weth)), 
            address(poolPositionManager), 
            address(manager), 
            address(mav),
            address(router),
            address(locker),
            address(staker)
        );

        // initalize
        broker.initialize(
            address(manager), address(base), address(staker), address(council), address(locker), address(board)
        );
        board.initialize(address(broker), address(hub));

        // get LP tokens
        _getLpTokens(alice);

        // get DAI
        _getDAI(address(this));
    }


    ////////////////////////////////////////////////////////////////
    /////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////
    
    /// @notice get lp tokens from whale
    function _getLpTokens(address account) internal returns (uint lpBalance) {
        vm.startPrank(lpTokensWhale);
        lpBalance = poolPosition.balanceOf(lpTokensWhale);
        poolPosition.transfer(account, lpBalance);
        vm.stopPrank();
    }

    /// @notice get DAI from whale
    function _getDAI(address account) internal returns (uint balance) {
        vm.startPrank(daiWhale);
        balance = dai.balanceOf(daiWhale);
        dai.transfer(account, balance);
        vm.stopPrank();
    }

//     function _getTokens() internal returns (uint, uint) {

//         uint tokenAAmount = IERC20(tokenA).balanceOf(tokenAWhale);
//         vm.startPrank(tokenAWhale);
//         emit log_named_uint("tokenA amount", tokenAAmount);
//         IERC20(tokenA).transfer(address(this), tokenAAmount);
//         vm.stopPrank();

//         vm.startPrank(tokenBWhale);
//         uint tokenBAmount = IERC20(tokenB).balanceOf(tokenBWhale);
//         emit log_named_uint("tokenB amount", tokenBAmount);
//         IERC20(tokenB).transfer(address(this), tokenBAmount);
//         vm.stopPrank();

//         uint balanceA = IERC20(tokenA).balanceOf(address(this));
//         uint balanceB = IERC20(tokenB).balanceOf(address(this));

//         return (balanceA, balanceB);
//     }

//     function _getMAV() internal returns (uint256) {
//         address mavWhale = 0x4eBC6D29CE557347858176177d3B5DaD8964cE71;
//         vm.startPrank(mavWhale);
//         uint balance = IERC20(mav).balanceOf(mavWhale);
//         IERC20(mav).transfer(address(this), balance);
//         vm.stopPrank();
//         return balance;
//     }
}