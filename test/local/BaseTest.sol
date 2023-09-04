// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import {Router} from "@maverick/Router.sol";
import {PoolPositionManager} from "@maverick/PoolPositionManager.sol";
import {PoolPositionAndRewardFactorySlim} from "@maverick/factories/PoolPositionAndRewardFactorySlim.sol";
import {IFactory} from "@maverick/interfaces/IFactory.sol";
import {IPoolPositionAndRewardFactorySlim} from "@maverick/interfaces/IPoolPositionAndRewardFactorySlim.sol";
import {IWETH9} from "@maverick/interfaces/external/IWETH9.sol";
import {VotingEscrow, IERC20 as MavIERC20} from "@maverick/VotingEscrow.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH9 as MockIWETH} from "contracts/periphery/base/utils/PeripheryPayments.sol";
import {WETH} from "test/local/utils/WETH.sol";

import {Locker} from "contracts/core/Locker.sol";
import {Board} from "contracts/periphery/Board.sol";
import {Manager} from "contracts/core/manager/Manager.sol";
import {Factory} from "contracts/core/manager/Factory.sol";
import {Staker} from "contracts/core/Staker.sol";
import {Hub} from "contracts/periphery/Hub.sol";
import {Broker} from "contracts/periphery/Broker.sol";
import {Base} from "contracts/periphery/Base.sol";
import {Council} from "contracts/periphery/Council.sol";

abstract contract BaseTest is Test {
    // protocol
    Locker public locker;
    Staker public staker;
    Factory public factory;
    Manager public manager;
    Broker public broker;
    Hub public hub;
    Board public board;
    Council public council;
    WETH public weth;
    Base public base;
    address public owner = address(this);

    // maverick
    MockERC20 public mav;
    PoolPositionAndRewardFactorySlim public poolPositionFactory;
    PoolPositionManager public poolPositionManager;
    VotingEscrow public veMav;
    Router public router;
    address public poolFactory;
    address public poll;

    // deploy params
    uint256 periodDuration = 7 days;
    uint256 maxSupply = 100000e18;
    address endpoint = address(86867);
    address mintTo = address(this);

    // other
    address public alice = address(478478);
    address public bob = address(5493489);
    MockERC20 public dai;

    function deploy() public {
        // external
        weth = new WETH();

        // maverick
        mav = new MockERC20("MAV", "MAV", 18);
        // (when Maverick deploys)
        // poolFactory = address(1);
        // poolPositionFactory = new PoolPositionAndRewardFactorySlim(IFactory(poolFactory));
        // poolPositionManager = new PoolPositionManager(IWETH9(address(weth)), IPoolPositionAndRewardFactorySlim(poolPositionFactory));
        // veMav = new VotingEscrow(MavIERC20(address(mav)));
        // router = new Router(IFactory(poolFactory), IWETH9(address(weth)));

        // LOCAL
        veMav = new VotingEscrow(MavIERC20(address(mav)));
        poolFactory = address(567567);
        poolPositionFactory = PoolPositionAndRewardFactorySlim(address(8738));
        poolPositionManager = PoolPositionManager(payable(address(874783)));
        router = Router(payable(address(67637)));

        // rogue
        locker = new Locker(address(mav), endpoint);
        broker = new Broker(address(veMav), address(mav), periodDuration);
        base = new Base(address(broker), maxSupply, endpoint, mintTo);
        staker = new Staker(IERC20(locker), address(broker), owner);
        factory = new Factory();
        council = new Council(IERC20(address(base)), address(broker), owner);
        board = new Board(address(mav), address(veMav), poll);
        manager = new Manager(address(factory), address(poolPositionFactory), address(broker), address(board));
        hub = new Hub(
            MockIWETH(address(weth)), 
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

        // mocks
        dai = new MockERC20("DAI", "DAI", 18);
        _mintMocks(address(this), 1e20 * 1e18);
        _mintMocks(alice, 1e20 * 1e18);
        _mintMocks(bob, 1e20 * 1e18);
    }

    /// @notice mint mocks
    function _mintMocks(address to, uint256 amount) internal {
        mav.mint(to, amount);
        dai.mint(to, amount);
    }
}
