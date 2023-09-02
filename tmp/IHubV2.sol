// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@maverick/interfaces/IPoolPositionSlim.sol";

interface IHub {
    error InvalidValue(uint256 value);
    error InvalidAmount(uint256 amount);
    error InvalidPoolPosition(address poolPosition);
    error SwapFailed();
    error InvalidOptimalAmount(uint256 optimalAmount);
    error InvalidDelta(uint256 delta);
    error InvalidDeltaA(uint256 deltaA);
    error InvalidDeltaB(uint256 deltaB);

    event ZappedSingle();
    event ZappedBoth();
    event UnzappedSingle();
    event UnzappedBoth();

    struct ZapSingleParams {
        address token;
        IPoolPositionSlim poolPosition;
        uint256 amount;
        uint256 desiredLpTokens;
        uint256 minLpTokens;
        bytes data;
        uint256 optimalAmountOutMin;
        uint256 optimalSqrtPriceLimitD18;
        uint256 minSharesOut;
        address recipient;
    }

    struct ZapBothParams {
        IPoolPositionSlim poolPosition;
        uint256 amountA;
        uint256 amountB;
        uint256 desiredLpTokens;
        uint256 minLpTokens;
        uint256 minSharesOut;
        address recipient;
    }

    struct UnzapSingleParams {
        IPoolPositionSlim poolPosition;
        address tokenOut;
        uint256 minAmountOut;
        uint256 shares;
        uint256 minAssetsOut;
        uint256 minTokenAOut;
        uint256 minTokenBOut;
        bytes[] data;
        address recipient;
    }

    struct UnzapBothParams {
        IPoolPositionSlim poolPosition;
        uint256 minAmountAOut;
        uint256 minAmountBOut;
        uint256 shares;
        uint256 minAssetsOut;
        address recipient;
    }
}