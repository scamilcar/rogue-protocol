// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {IRouter} from "@maverick/interfaces/IRouter.sol";
// import {Path} from '@maverick/libraries/Path.sol';

// import {Babylonian} from "./libraries/Babylonian.sol";

// // import {Babylonian} from 


// library Compound {
//     using SafeERC20 for IERC20;

//     error InvalidPath(address tokenIn);
//     error InvalidTarget();

//     event Compounded(uint256 lpTokens);



//     // TODO: if token is optionClaim don't swap but _notifyRewardAmount()
//     // TODO put this in another place if 
//     function compound() external onlyCompounder {
//         if (!compound) revert InvalidMode();
//         IReward.RewardInfo[] memory info = lpReward.rewardInfo();
//         uint256 length = info.length;
//         if (length != params.data.length || length != params.amountsMin.length) revert InvalidLength();
//         if (params.target != address(tokenA) && params.target != address(tokenB)) revert InvalidTarget();
//         uint256 temp;
//         for (uint256 i = 1; i < length; i++) {
//             address token = address(info[i].rewardToken);
//             if (isApprovedRewardToken[token]) {
//                 uint256 reward = lpReward.getReward(address(this), uint8(i));
//                 if (token == target) {
//                     temp += reward;
//                 } else {
//                     temp += Utils.target(router, token, reward, params.paths[i], params.amountsMin[i], params.target);
//                 }
//             }
//         }
//         // _temp should be equal to the amount claimed in the most liquid token of the pool
//         if (temp == 0) revert InvalidCompounding();
//         (uint256 lpTokens, uint256 _dustA, uint256 _dustB) = Utils.compound(
//             router,
//             poolPosition,
//             address(tokenA),
//             address(tokenB),
//             temp, 
//             params.target, 
//             params.optimalAmountOutMin, 
//             params.optimalSqrtPriceLimitX96,
//             params.desiredLpTokens, 
//             params.minLpTokens
//         );

//         dustA += _dustA;
//         dustB += _dustB;

//         return lpTokens;
//     }















//     // swap tokens during compounding
//     function target(
//         IRouter router,
//         address token, 
//         uint256 amount, 
//         bytes calldata path, 
//         uint256 amountMin, 
//         address target
//     ) internal returns (uint256 out) {

//         (IERC20 tokenIn,,) = path.decodeFirstPool();
//         if (address(tokenIn) != token) revert InvalidPath(address(tokenIn));
//         uint256 preBalance = IERC20(target).balanceOf(address(this));
//         IRouter.ExactInputParams memory params = IRouter.ExactInputParams({
//             path: path,
//             recipient: address(this),
//             deadline: block.timestamp,
//             amountIn: amount,
//             amountOutMin: amountMin
//         });
//         IERC20(token).safeApprove(address(router), amount);
//         out = router.exactInput(params);
//         uint256 delta = IERC20(target).balanceOf(address(this)) - preBalance;
//         if (delta != out) revert InvalidTarget();
//     }


//     function compound(
//         IRouter router,
//         IPoolPositionManager poolPositionManager,
//         IPoolPositionSlim poolPosition,
//         address tokenA,
//         address tokenB,
//         uint256 amount,
//         address tokenIn, 
//         uint256 optimalAmountOutMin,
//         uint256 optimalSqrtPriceLimitX96,
//         uint256 desiredLpTokens,
//         uint256 minLptokens
//     ) internal returns(uint256, uint256, uint256) {

//         (uint256 reserveA, uint256 reserveB) = poolPosition.getReserves();
//         uint256 fee = poolPosition.pool().fee();
//         uint256 optimalAmount;
//         uint256 amountA;
//         uint256 amountB;

//         if (tokenIn == tokenA) {
//             optimalAmount = getOptimalAmount(reserveA, amount, fee);
//             amountB = swapSingleInput(
//                 router,
//                 tokenIn,
//                 tokenB,
//                 optimalAmount,
//                 optimalAmountOutMin,
//                 optimalSqrtPriceLimitX96
//             );
//             amountA = optimalAmount - amountB;
//         } else {
//             optimalAmount = getOptimalAmount(reserveB, amount, fee);
//             amountA = swapSingleInput(
//                 router,
//                 tokenIn,
//                 tokenA,
//                 optimalAmount,
//                 optimalAmountOutMin,
//                 optimalSqrtPriceLimitX96
//             );
//             amountB = optimalAmount - amountA;
//         }

//         (uint256 lpTokens, uint256 addedA, uint256 addedB) = addLiquidity(
//             poolPositionManager,
//             poolPosition,
//             amountA,
//             amountB,
//             desiredLpTokens,
//             minLptokens
//         );

//         (uint256 deltaA, uint256 deltaB) = dust(amountA, amountB, addedA, addedB);

//         emit Compounded(lpTokens);

//         return (lpTokens, deltaA, deltaB);
//     }

//     function getOptimalAmount(uint256 reserve, uint256 amount, uint256 fee) internal returns(uint256) {
//         Babylonian.sqrt(reserve * (reserve * 398920729 + amount * 398920000)) - reserve * (19973) / 19946;
//     }

//     function swapSingleInput(
//         IRouter router, 
//         IPoolPositionSlim poolPosition, 
//         address tokenIn, 
//         address tokenOut, 
//         uint256 amount,
//         uint256 amountOutMinimum,
//         uint256 sqrtPriceLimitX96
//         ) internal returns(uint256) {

//         IRouter.ExactInputSingleParams params = IRouter.ExactInputSingleParams({
//             tokenIn: tokenIn,
//             tokenOut: tokenOut,
//             pool: poolPosition.pool(),
//             recipient: address(this),
//             deadline: block.timestamp,
//             amountIn: amount,
//             amountOutMinimum: amountOutMinimum,
//             sqrtPriceLimitX96: sqrtPriceLimitX96
//         });

//         return router.exactInputSingle(params);
//     }

//     function addLiquidity(
//         IPoolPositionManager poolPositionManager,
//         IPoolPositionSlim poolPosition,
//         uint256 amountA, 
//         uint256 amountB, 
//         uint256 desiredLpTokens, 
//         uint256 minLptokens
//         ) internal returns(uint256 lpTokens, uint256 addedA, uint256 addedB) {

//         IPoolPositionManager.AddLimits limits = IPoolPositionManager.AddLimits({
//             maxTokenAAmount: amountA,
//             maxTokenBAmount: amountB,
//             deadline: block.timestamp,
//             stakeInReward: true
//         });

//         (lpTokens, addedB, addedB) = poolPositionManager.addLiquidityToPoolPosition(
//             poolPosition, 
//             address(this), 
//             desiredLpTokens, 
//             minLptokens,
//             limits
//         );
//     }

//     // should accumulate tokens not added to the pool for the compounder as "incentive"
//     function dust(uint256 desiredA, uint256 desiredB, uint256 addedA, uint256 addedB) internal returns(uint256 deltaA, uint256 deltaB) {
//         if (addedA < desiredA) {
//             deltaA += desiredA - addedA;
//         }
//         if (addedB < desiredB) {
//             deltaB += desiredB - addedB;
//         }
//     }
// }