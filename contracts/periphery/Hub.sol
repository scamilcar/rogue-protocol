// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPoolPositionSlim} from "@maverick/interfaces/IPoolPositionSlim.sol";
import {IPoolPositionManager} from "@maverick/interfaces/IPoolPositionManager.sol";
// import {IPoolPositionAndRewardFactorySlim} from "@maverick/interfaces/IPoolPositionAndRewardFactorySlim.sol";
// import {Path} from "@maverick/libraries/Path.sol";
import {IPool} from "@maverick/interfaces/IPool.sol";
import {IRouter} from "@maverick/interfaces/IRouter.sol";
import {ISlimRouter} from "@maverick/interfaces/ISlimRouter.sol";

import "./base/ERC4626RouterBase.sol";

import {IManager} from "contracts/core/interfaces/IManager.sol";
import {ILocker} from "contracts/core/interfaces/ILocker.sol";
import {IStaker} from "contracts/core/interfaces/IStaker.sol";

/*
Note: V1, V2 should allow to zap
*/

contract Hub is ERC4626RouterBase {
    // using Path for bytes;
    using SafeERC20 for IERC20;

    struct AddParams {
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 amountAMax; 
        uint256 amountBMax; 
        uint256 desiredLpAmount; 
        uint256 minLpAmount;
        uint256 deadline;
    }

    struct RemoveParams {
        uint256 minAmountAOut;
        uint256 minAmountBOut;
        uint256 deadline;
    }

    struct EnterParams {
        address tokenIn;
        AddParams addParams;
    }

    struct ExitParams {
        RemoveParams removeParams;
        bytes[] data;
    }

    struct SwapSingleParams {
        IPool pool;
        uint256 deadline;
        uint256 amountOutMinimum;
        uint256 sqrtPriceLimitD18;
    }

    struct SwapInputParams {
        bytes path;
        uint256 deadline;
        uint256 amountOutMinimum;
    }

    error InsufficientInputAmount();
    error InsufficientOutputAmount(uint256 outputAmount);
    error ErrorSwapping(address tokenIn);
    error WrongValue();

    /// @notice The manager contract
    IManager public immutable manager;

    /// @notice The pool position manager contract
    IPoolPositionManager public immutable poolPositionManager;

    /// @notice The MAV token
    IERC20 public immutable mav;

    /// @notice The router contract
    IRouter public immutable router;

    /// @notice The locker contract
    ILocker public immutable locker;

    /// @notice The staker contract
    IStaker public immutable staker;

    /// @notice The pool position and reward factory contract
    // IPoolPositionAndRewardFactorySlim public immutable poolPositionFactory;

    /// @param _WETH The WETH contract
    /// @param _poolPositionManager The pool position manager contract
    /// @param _manager The manager contract
    /// @param _mav The MAV token
    /// @param _router The router contract
    /// @param _locker The locker contract
    /// @param _staker The staker contract
    constructor(
        IWETH9 _WETH,
        address _poolPositionManager,
        address _manager,
        address _mav,
        address _router,
        address _locker, 
        address _staker
        // address _poolPositionFactory,
        ) PeripheryPayments(_WETH) {

        manager = IManager(_manager);
        poolPositionManager = IPoolPositionManager(_poolPositionManager);
        mav = IERC20(_mav);
        // poolPositionFactory = IPoolPositionAndRewardFactorySlim(_poolPositionFactory);
        router = IRouter(_router);
        locker = ILocker(_locker);
        staker = IStaker(_staker);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Booster ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Deposits both tokens into a Maverick Boosted Position and mint shares of Booster
    /// @param booster The booster contract
    /// @param recipient The recipient of the shares
    /// @param minSharesOut The minimum amount of shares to mint
    /// @param params The parameters used to add liquidity
    /// @return sharesOut The amount of shares minted
    function deposit(
        IERC4626 booster,
        address recipient,
        uint256 minSharesOut,
        AddParams calldata params
    ) external returns (uint256 sharesOut) {

        params.tokenA.safeTransferFrom(msg.sender, address(this), params.amountAMax);
        params.tokenB.safeTransferFrom(msg.sender, address(this), params.amountBMax);

        address poolPosition = IManager(manager).boosterPosition(address(booster));

        (uint256 lpTokens) = _addLiquidity(IPoolPositionSlim(poolPosition), params);

        sharesOut = deposit(booster, recipient, lpTokens, minSharesOut);

        _refund(params.tokenA, params.tokenB);
    }

    /// @notice Redeem shares of Booster and withdraw liquidity from Maverick Boosted Position
    /// @param booster The booster contract
    /// @param shares The amount of shares to redeem
    /// @param recipient The recipient of the tokens
    /// @param params The parameters used to remove liquidity
    /// @return amountAOut The amount of token A withdrawn
    /// @return amountBOut The amount of token B withdrawn
    function redeem(
        IERC4626 booster,
        uint256 shares,
        address recipient,
        RemoveParams calldata params
    ) external returns (uint256 amountAOut, uint256 amountBOut) {

        address poolPosition = IManager(manager).boosterPosition(address(booster));

        IERC20(poolPosition).safeTransferFrom(msg.sender, address(this), shares);

        (amountAOut, amountBOut) = _removeLiquidity(IPoolPositionSlim(poolPosition), recipient, shares, params);
    }

    /// @notice allows staker and council to compounds rewards into rMAV and dROG
    function compound(address tokenIn, uint256 amountIn, address tokenOut, bytes calldata data) external returns (uint256 sharesOut) {}

    /// @notice allows compounding for a booster
    function compound(address booster, uint256 amountIn, bytes calldata data) external returns (uint256 sharesOut) {}

    /// @notice Allows deposit of any tokens, swaps and add liquidity to a Maverick Boosted Position, and mint shares of Booster
    function enter(
        IERC4626 booster, 
        address tokenIn, 
        uint256 amount, 
        address recipient, 
        EnterParams calldata params
    ) external returns (uint256 sharesOut) {}

    /// @notice Allows redeem of shares of Booster, remove liquidity from a Maverick Boosted Position, and withdraw ans swap to any token
    /// @param booster The booster contract
    /// @param tokenOut The token to swap to
    /// @param shares The amount of shares to redeem
    /// @param recipient The recipient of the tokens
    /// @param params The parameters used to remove liquidity
    /// @return amountOut The amount of token withdrawn
    function exit(
        IERC4626 booster, 
        IERC20 tokenOut, 
        uint256 shares, 
        address recipient, 
        ExitParams calldata params
    ) external returns(uint256 amountOut) {

        IPoolPositionSlim poolPosition = IPoolPositionSlim(IManager(manager).boosterPosition(address(booster)));

        IPool pool = poolPosition.pool();
        (address tokenA, address tokenB) = (address(pool.tokenA()), address(pool.tokenB())); // Why cant assign IERC20 to IERC20?
        IERC20(address(poolPosition)).safeTransferFrom(msg.sender, address(this), shares);

        (uint256 amountAOut, uint256 amountBOut) = _removeLiquidity(poolPosition, address(this), shares, params.removeParams);

        amountOut += _swap(IERC20(tokenA), tokenOut, amountAOut, recipient, params.data[0]);
        amountOut += _swap(IERC20(tokenB), tokenOut, amountBOut, recipient, params.data[1]);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// Locker /////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice Swap any token to MAV, deposit on Locker and stake if `stake` is true
    /// @param token The token to swap
    /// @param amount The amount of token to swap
    /// @param recipient The recipient of the tokens
    /// @param params The parameters used to swap
    /// @param stake Whether to stake the MAV or not
    /// @return mavOut The amount of MAV deposited
    function move(
        IERC20 token,
        uint256 amount,
        address recipient,
        SwapInputParams calldata params,
        bool stake
    ) external payable returns (uint256 mavOut) {

        if (amount == 0) revert InsufficientInputAmount();
        if (address(token) == address(WETH9)) {
            if (msg.value != amount) revert WrongValue();
            wrapWETH9();
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        if (stake) {
            mavOut = _swapInput(token, mav, amount, address(this), params);
            mav.safeApprove(address(locker), mavOut);
            locker.deposit(mavOut, address(this));
            IERC20(address(locker)).safeApprove(address(staker), mavOut);
            staker.stake(mavOut, recipient);
        } else {
            mavOut = _swapInput(token, mav, amount, address(this), params);
            mav.safeApprove(address(locker), mavOut);
            locker.deposit(mavOut, recipient);
        }
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Internal ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice internal add liquidity method
    function _addLiquidity(IPoolPositionSlim poolPosition, AddParams calldata params) internal returns(uint256 lpTokens) {

        IPoolPositionManager.AddLimits memory limits = IPoolPositionManager.AddLimits({
            maxTokenAAmount: params.amountAMax,
            maxTokenBAmount: params.amountBMax,
            deadline: params.deadline,
            stakeInReward: true
        });

        params.tokenA.safeApprove(address(poolPositionManager), params.amountAMax);
        params.tokenB.safeApprove(address(poolPositionManager), params.amountBMax);

        (lpTokens,,) = poolPositionManager.addLiquidityToPoolPosition(
            poolPosition, 
            address(this), 
            params.desiredLpAmount, 
            params.minLpAmount,
            limits
        );
    }
    
    /// @notice internal remove liquidity method
    function _removeLiquidity(
        IPoolPositionSlim poolPosition,
        address recipient,
        uint256 amount,
        RemoveParams calldata params
    ) internal returns (uint256 amountA, uint256 amountB) {

        IERC20(address(poolPosition)).safeApprove(address(poolPositionManager), amount);

        (amountA, amountB) = poolPositionManager.removeLiquidityFromPoolPosition(
            poolPosition,
            recipient,
            amount,
            params.minAmountAOut,
            params.minAmountBOut,
            params.deadline
        );
    }

    /// @notice execute a single hop swap
    function _swapSingle(
        IERC20 tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient,
        SwapSingleParams calldata params
    ) internal returns(uint256 amountOut) {
    
        tokenIn.safeApprove(address(router), amountIn);

        ISlimRouter.ExactInputSingleParams memory inputParams = ISlimRouter.ExactInputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: tokenOut,
            pool: params.pool,
            recipient: recipient,
            deadline: params.deadline,
            amountIn: amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitD18: params.sqrtPriceLimitD18
        });

        amountOut = router.exactInputSingle(inputParams);

    }

    /// @notice execute a multi hop swap
    function _swapInput(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        address recipient,
        SwapInputParams calldata params
    ) internal returns (uint256 amountOut) {

        uint256 preswapBalance = tokenOut.balanceOf(recipient);

        tokenIn.safeApprove(address(router), amountIn);
        IRouter.ExactInputParams memory inputParams = IRouter.ExactInputParams({
            path: params.path,
            recipient: recipient,
            deadline: params.deadline,
            amountIn: amountIn, 
            amountOutMinimum: params.amountOutMinimum
        });

        amountOut = router.exactInput(inputParams);
        uint256 delta = tokenOut.balanceOf(recipient) - preswapBalance;
        if (delta < params.amountOutMinimum) revert InsufficientOutputAmount(delta);
    }

    /// @notice execute a multi hop swap with data encoded
    function _swap(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, address recipient, bytes calldata data) internal returns (uint256 out) {
        uint256 preswapBalance = tokenOut.balanceOf(recipient);

        tokenIn.safeApprove(address(router), amountIn);
        (bool success, bytes memory returnData) = address(router).call(data);
        if (!success) revert ErrorSwapping(address(tokenIn));
        out = abi.decode(returnData, (uint256));

        uint256 delta = tokenOut.balanceOf(recipient) - preswapBalance;
        if (delta == 0) revert InsufficientOutputAmount(delta);
    }

    /// @notice refund any remaining tokens
    function _refund(IERC20 tokenA, IERC20 tokenB) internal {
        (uint256 balanceA, uint256 balanceB) = (tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)));
        if (balanceA > 0) tokenA.safeTransfer(msg.sender, balanceA);
        if (balanceB > 0) tokenB.safeTransfer(msg.sender, balanceB);
    }
}