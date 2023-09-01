// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFees {

    error Initialized();
    error InvalidLength();
    error AllocationsTooHigh();
    error InvalidDividends();
    error UnauthorizedBooster(address booster);
    error UnauthorizedCompounder(address compounder);
    error InvalidMode();
    error NotBooster(address booster);

    struct Quotas {
        uint256 rewardRatio;
        uint256 dividendRatio;
    }

    struct Allocations {
        Quotas liquidity;
        Quotas lock;
        Quotas option;
    }
    
    function rogueTreasury() external view returns (address);
    function notifyBrokerFees(address quoteToken, uint256 amount) external;
}