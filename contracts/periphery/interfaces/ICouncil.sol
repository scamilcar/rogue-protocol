// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICouncil {

    error DurationTooShort(uint256 minDuration, uint256 duration);
    error DurationTooLong(uint256 maxDuration, uint256 duration);
    error TooEarly(uint256 timestamp, uint256 endtime);
    error InvalidParams();
    error WrongRatio(uint256 minRatio, uint256 maxRatio);
    error WrongDuration(uint256 minDuration, uint256 maxDuration);
    error InvalidExit();

    event Exited(address indexed owner, uint256 shares, uint256 exitShares, uint256 duration);
    event Left(address indexed owner, uint256 exitShares, uint256 shares);
    event ParametersUpdated(
        uint256 minExitDuration, 
        uint256 maxExitDuration, 
        uint256 minExitRatio, 
        uint256 maxExitRatio, 
        uint256 compensationRatio
    );

    struct UserInfo {
        uint256 allocated;
        uint256 exiting; 
    }

    struct ExitInfo {
        uint256 shares;
        uint256 exitShares;
        uint256 compensation;
        uint256 time;
    }

    struct Params {
        uint256 minExitDuration;
        uint256 maxExitDuration;
        uint256 minExitRatio;
        uint256 maxExitRatio;
        uint256 compensationRatio;
    }
}