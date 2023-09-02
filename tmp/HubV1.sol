// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPoolPositionSlim} from "@maverick/interfaces/IPoolPositionSlim.sol";
import {IPoolPositionAndRewardFactorySlim} from "@maverick/interfaces/IPoolPositionAndRewardFactorySlim.sol";
import {IPoolPositionManager} from "@maverick/interfaces/IPoolPositionManager.sol";
import {Path} from "@maverick/libraries/Path.sol";
import {IPool} from "@maverick/interfaces/IPool.sol";
import {IRouter} from "@maverick/interfaces/IRouter.sol";
import {ISlimRouter} from "@maverick/interfaces/ISlimRouter.sol";

import "./external/ERC4626RouterBase.sol";

import {IHub} from "./interfaces/IHub.sol";
import {IManager} from "contracts/core/interfaces/IManager.sol";
import {Babylonian} from "./libraries/Babylonian.sol";

// TODO getOptimalAmount according to fee
// TODO implement unzapSingle and unzapPair
// TODO refund when adding liquidity to pool position
// TODO pass slippage tolerance so that it can be used in the router without having to compute it on the front end
// TODO refund tokens when adding liquidity

contract Hub is IHub, ERC4626RouterBase {
    using Path for bytes;
    using SafeERC20 for IERC20;

    IManager public immutable manager;
    IPoolPositionManager public immutable poolPositionManager;
    IRouter public immutable maverickRouter;
    IPoolPositionAndRewardFactorySlim public immutable poolPositionFactory;

    constructor(
        IWETH9 _WETH,
        address _poolPositionManager,
        address _poolPositionFactory,
        address _router,
        address _manager
        ) PeripheryPayments(_WETH) {

        manager = IManager(_manager);
        poolPositionManager = IPoolPositionManager(_poolPositionManager);
        maverickRouter = IRouter(_router);
        poolPositionFactory = IPoolPositionAndRewardFactorySlim(_poolPositionFactory);
    }


    // allow to zap from 1 token to any pool pool position if there is enough liquidity
    function zapSingle(ZapSingleParams calldata params) public payable returns(uint256 sharesOut) {

        if (!poolPositionFactory.isPoolPosition(params.poolPosition)) revert InvalidPoolPosition(address(params.poolPosition));
        if (params.token == address(WETH9)) {
            if (msg.value != params.amount) revert InvalidValue(msg.value);
            wrapWETH9();
        } else {
            pullToken(ERC20(params.token), params.amount, address(this));
        }

        IPool pool = params.poolPosition.pool();
        (address tokenA, address tokenB) = (address(pool.tokenA()), address(pool.tokenB()));

        address tempToken;
        uint256 tempAmount;

        // get one of the tokens of the pool (the most liquid one)
        if (params.token != tokenA && params.token != tokenB) {
            (tempToken, tempAmount) = _swapIn(params.token, tokenA, tokenB, params.amount, params.data);
        } else {
            (tempToken, tempAmount) = (params.token, params.amount);
        }

        // swap optimal amount of token to the other token of the pool
        (uint256 amountA, uint256 amountB) = _swapOptimalAmount(
            params.poolPosition,
            tempToken,
            tempAmount,
            pool,
            tokenA,
            tokenB,
            params.optimalAmountOutMin,
            params.optimalSqrtPriceLimitD18
        );

        // add liquidity to pool position
        uint256 lpTokens = _addLiquidity(
            params.poolPosition,
            tokenA,
            tokenB,
            amountA, 
            amountB, 
            params.desiredLpTokens, 
            params.minLpTokens
        );

        address vault = manager.positionVault(address(params.poolPosition));
        IERC20(address(params.poolPosition)).approve(vault, lpTokens);
        // deposit to vault for caller
        sharesOut = deposit(IERC4626(vault), params.recipient, lpTokens, params.minSharesOut);

        emit ZappedSingle();
    }

    // should zap if caller already has the 2 tokens of the pool
    /// @dev tokenA and tokenB should be approved to use
    function zapBoth(ZapBothParams calldata params) public payable returns(uint256 sharesOut){

        IPool pool = params.poolPosition.pool();
        (address tokenA, address tokenB) = (address(pool.tokenA()), address(pool.tokenB()));
        IERC20(tokenA).transferFrom(msg.sender, address(this), params.amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), params.amountB);
        // add liquidity to pool position
        uint256 lpTokens = _addLiquidity(
            params.poolPosition,
            tokenA,
            tokenB,
            params.amountA, 
            params.amountB, 
            params.desiredLpTokens, 
            params.minLpTokens
        );

        address vault = manager.positionVault(address(params.poolPosition));
        IERC20(address(params.poolPosition)).approve(vault, lpTokens);
        // deposit to vault for caller
        sharesOut = deposit(IERC4626(vault), params.recipient, lpTokens, params.minSharesOut);

        emit ZappedBoth();
    }

    // should unzap and return 1 selected token
    function unzapSingle(UnzapSingleParams calldata params) external returns(uint256 amountOut){

        uint256 recipientPreBalance = IERC20(params.tokenOut).balanceOf(params.recipient);

        IPool pool = params.poolPosition.pool();
        (address tokenA, address tokenB) = (address(pool.tokenA()), address(pool.tokenB()));

        address vault = manager.positionVault(address(params.poolPosition));
        IERC20(vault).transferFrom(msg.sender, address(this), params.shares);

        uint256 assets = redeem(IERC4626(vault), address(this), params.shares, params.minAssetsOut);
        (uint256 amountA, uint256 amountB) = _removeLiquidity(
            params.poolPosition,
            address(this),
            assets,
            params.minTokenAOut,
            params.minTokenBOut,
            block.timestamp
        );

        amountOut = _swapOut(params.tokenOut, tokenA, tokenB, amountA, amountB, params.data);

        uint256 delta = IERC20(params.tokenOut).balanceOf(params.recipient) - recipientPreBalance;
        if (delta < params.minAmountOut) revert InvalidDelta(amountOut);
        if (params.tokenOut == address(WETH9)) {
            unwrapWETH9(1, params.recipient);
        }
        emit UnzappedSingle();
    }

    // should unzap and return 2 tokens of the pool
    function unzapBoth(UnzapBothParams calldata params) external returns(uint256 amountA, uint256 amountB) {

        IPool pool = params.poolPosition.pool();
        (address tokenA, address tokenB) = (address(pool.tokenA()), address(pool.tokenB()));

        uint256 recipientPreBalanceA = IERC20(tokenA).balanceOf(params.recipient);
        uint256 recipientPreBalanceB = IERC20(tokenB).balanceOf(params.recipient);

        address vault = manager.positionVault(address(params.poolPosition));
        IERC20(vault).transferFrom(msg.sender, address(this), params.shares);
        uint256 assets = redeem(IERC4626(vault), address(this), params.shares, params.minAssetsOut);
        (amountA, amountB) = _removeLiquidity(
            params.poolPosition,
            params.recipient,
            assets,
            params.minAmountAOut,
            params.minAmountBOut,
            block.timestamp
        );

        uint256 deltaA = IERC20(tokenA).balanceOf(params.recipient) - recipientPreBalanceA;
        uint256 deltaB = IERC20(tokenB).balanceOf(params.recipient) - recipientPreBalanceB;

        if (deltaA < params.minAmountAOut) revert InvalidDeltaA(deltaA);
        if (deltaB < params.minAmountBOut) revert InvalidDeltaB(deltaB);

        emit UnzappedBoth();
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Internal ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @dev _to parameter in _swapData MUST be set to the address of this contract
    function _swapIn(
        address token,
        address tokenA,
        address tokenB,
        uint256 amount,
        bytes memory swapData
    ) internal returns (address tokenOut, uint256 out) {

        IERC20(token).approve(address(maverickRouter), amount);
        uint256 preBalanceA = IERC20(tokenA).balanceOf(address(this));

        (bool success, bytes memory data) = address(maverickRouter).call(swapData);
        if (!success) revert SwapFailed();
        out = abi.decode(data, (uint256));

        uint256 postBalanceA = IERC20(tokenA).balanceOf(address(this));
        preBalanceA != postBalanceA ? tokenOut = tokenA : tokenOut = tokenB;
    }

    function _swapOut(
        address tokenOut,
        address tokenA,
        address tokenB,
        uint256 amountA, 
        uint256 amountB,
        bytes[] calldata data
    ) internal returns(uint256 amountOut){
        if (tokenOut == tokenA) { 
            amountOut += amountA;
        } else {
            amountOut += _swapInput(data[0]); 
            }
        if (tokenOut == tokenB) {
            amountOut += amountB;
        } else {
            amountOut += _swapInput(data[1]); 
        }
    }

    function _swapOptimalAmount(
        IPoolPositionSlim poolPosition,
        address tokenIn,
        uint256 amountIn,
        IPool pool,
        address tokenA,
        address tokenB,
        uint256 amountOutMinimum,
        uint256 sqrtPriceLimitD18
    ) internal returns (uint256 amountA, uint256 amountB) {

        (uint256 reserveA, uint256 reserveB) = poolPosition.getReserves();
        if (tokenIn == tokenA) {
            uint256 optimalAmount = getOptimalAmount(reserveA, amountIn, pool.fee());
            if (optimalAmount <= 0) revert InvalidOptimalAmount(optimalAmount);
            amountB = _swapSingleInput(
                pool,
                tokenIn,
                tokenB,
                optimalAmount,
                amountOutMinimum,
                sqrtPriceLimitD18
            );
            amountA = amountIn - optimalAmount;
        } else {
            uint256 optimalAmount = getOptimalAmount(reserveB, amountIn, pool.fee());
            if (optimalAmount <= 0) revert InvalidOptimalAmount(optimalAmount);
            amountA = _swapSingleInput(
                pool,
                tokenIn,
                tokenA,
                optimalAmount,
                amountOutMinimum,
                sqrtPriceLimitD18
            );
            amountB = amountIn - optimalAmount;
        }
    }

    /// @dev recipient params must be send to receiver
    function _swapInput(bytes calldata swapData) internal returns (uint256 out) {
        (bool success, bytes memory data) = address(maverickRouter).call(swapData);
        if (!success) revert SwapFailed();
        out = abi.decode(data, (uint256));
    }

    function _swapSingleInput(
        IPool pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 sqrtPriceLimitD18
    ) internal returns (uint256 amountOut) {

        IERC20(tokenIn).approve(address(maverickRouter), amountIn);
        ISlimRouter.ExactInputSingleParams memory params = ISlimRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            pool: pool,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitD18: sqrtPriceLimitD18
        });

        return maverickRouter.exactInputSingle(params);
    }

    // TODO derive proper formula depending on fee
    function getOptimalAmount(uint256 reserve, uint256 amount, uint256 fee) internal returns(uint256) {
        // fee = 
        return Babylonian.sqrt(reserve * (reserve * 398920729 + amount * 398920000)) - reserve * (19973) / 19946;
    }

    function _addLiquidity(
        IPoolPositionSlim poolPosition,
        address tokenA,
        address tokenB,
        uint256 amountA, 
        uint256 amountB, 
        uint256 desiredLpTokens, 
        uint256 minLptokens
        ) internal returns(uint256 lpTokens) {

        IPoolPositionManager.AddLimits memory limits = IPoolPositionManager.AddLimits({
            maxTokenAAmount: amountA,
            maxTokenBAmount: amountB,
            deadline: block.timestamp,
            stakeInReward: true
        });

        IERC20(tokenA).approve(address(poolPositionManager), amountA);
        IERC20(tokenB).approve(address(poolPositionManager), amountB);

        (lpTokens,,) = poolPositionManager.addLiquidityToPoolPosition(
            poolPosition, 
            address(this), 
            desiredLpTokens, 
            minLptokens,
            limits
        );
    }
    

    function _removeLiquidity(
        IPoolPositionSlim poolPosition,
        address recipient,
        uint256 amount,
        uint256 minTokenAOut,
        uint256 minTokenBOut,
        uint256 deadline
    ) internal returns (uint256 amountA, uint256 amountB) {

        IERC20(address(poolPosition)).approve(address(poolPositionManager), amount);
        (amountA, amountB) = poolPositionManager.removeLiquidityFromPoolPosition(
            poolPosition,
            recipient,
            amount,
            minTokenAOut,
            minTokenBOut,
            deadline
        );
    }
}