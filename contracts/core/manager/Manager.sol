// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPoolPositionAndRewardFactorySlim} from '@maverick/interfaces/IPoolPositionAndRewardFactorySlim.sol';
import {IPoolPositionSlim} from '@maverick/interfaces/IPoolPositionSlim.sol';

import {IFactory} from 'contracts/core/interfaces/IFactory.sol';
import {IBooster} from 'contracts/core/interfaces/IBooster.sol';
import {IBroker} from 'contracts/periphery/interfaces/IBroker.sol';
import {IBoard} from 'contracts/periphery/interfaces/IBoard.sol';

contract Manager is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    error InvalidPoolPosition(address poolPosition);
    error BoosterExists(address booster);
    error InvalidProtocolFee(uint256 protocolFee);
    error InvalidMode();
    error InvalidCompounder();

    event BoosterCreated(address poolPosition, address booster);
    event BoosterRemoved(address booster);

    struct Info {
        address compounder;
        bool compounding;
    }

    /// @notice address of the pool position factory
    IPoolPositionAndRewardFactorySlim public immutable poolPositionFactory;

    /// @notice address of the factory
    IFactory public immutable factory;

    /// @notice address of the broker
    address public immutable broker;

    /// @notice address of the board
    address public board;

    /// @notice protocol fee
    uint public protocolFee;

    /// @notice option period duration
    uint256 public baseMinRewardAmount;

    /// @notice reward duration of liquity mining
    uint256 public basePeriodDuration;

    /// @notice list of boosters
    EnumerableSet.AddressSet private _boosters;

    /// @notice mapping of reward token to booster
    mapping(address reward => address booster) public rewardBooster;

    /// @notice mapping of pool position to booster
    mapping(address position => address booster) public positionBooster;

    /// @notice mapping of booster to info
    mapping(address booster => Info info) public boosterInfo;

    constructor(
        address _factory,
        address _poolPositionFactory,
        address _broker,
        address _board
    ) {
        factory = IFactory(_factory);
        poolPositionFactory = IPoolPositionAndRewardFactorySlim(_poolPositionFactory);
        broker = _broker;
        board = _board;
    }

    ////////////////////////////////////////////////////////////////
    ///////////////////////////// Views ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @param index index of the booster
    function boosterAt(uint index) external view returns (address) {
        return _boosters.at(index);
    }

    /// @notice returns the number of boosters
    function boostersLength() external view returns (uint) {
        return _boosters.length();
    }

    /// @notice returns true if the address is a booster
    /// @param booster address of the booster
    function isBooster(address booster) external view returns (bool) {
        return _boosters.contains(booster);
    }

    /// @notice returns the list of boosters
    function boosters() external view returns (address[] memory) {
        return _boosters.values();
    }

    /// @notice returns true if the address is a booster reward
    /// @param _booster address of the booster
    /// @param _token address of the reward token
    function isBoosterReward(address _booster, address _token) external view returns (bool) {
        return IBooster(_booster).isApprovedRewardToken(_token);
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Create ////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice create a new booster
    /// @param _poolPosition address of the pool position
    function create(address _poolPosition) external onlyOwner returns (address booster) {
        IPoolPositionSlim poolPosition = IPoolPositionSlim(_poolPosition);
        if (!poolPositionFactory.isPoolPosition(poolPosition)) revert InvalidPoolPosition(_poolPosition);
        address lpReward = address(poolPositionFactory.getLpRewardByPP(poolPosition));
        if (rewardBooster[lpReward] != address(0)) revert BoosterExists(lpReward);
        string memory name = string(abi.encodePacked("Rogue Shares - ", IERC20Metadata(_poolPosition).name()));
        string memory symbol = string(abi.encodePacked("rogue-", IERC20Metadata(_poolPosition).symbol()));
        booster = factory.deploy(_poolPosition, lpReward, broker, board, name, symbol);
        rewardBooster[lpReward] = booster;
        positionBooster[_poolPosition] = booster;
        boosterInfo[booster] = Info({compounder: owner(),compounding: false});
        _boosters.add(booster);
        IBroker _broker = IBroker(broker);
        IBooster(booster).addNewRewardToken(_broker.mav(), baseMinRewardAmount, basePeriodDuration);
        IBooster(booster).addNewRewardToken(_broker.claimToken(), baseMinRewardAmount, basePeriodDuration);

        emit BoosterCreated(_poolPosition, booster);
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Restricted //////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice remove a booster from the list
    /// @param _booster address of the booster
    function removeBooster(address _booster) external onlyOwner {
        Info storage info = boosterInfo[_booster];
        delete info.compounder; 
        delete info.compounding;
        _boosters.remove(_booster);
        emit BoosterRemoved(_booster);
    }

    /// @notice add a new reward token to a booster
    /// @param _booster address of the booster
    /// @param _token address of the reward token
    /// @param _minimumAmount minimum amount of the reward token to be notified
    /// @param _duration duration of the reward distribution
    function addBoosterReward(address _booster, address _token, uint256 _minimumAmount, uint _duration) external onlyOwner {
        IBooster(_booster).addNewRewardToken(_token, _minimumAmount, _duration);
    }

    /// @notice remove a reward token from a booster
    /// @param _booster address of the booster
    /// @param token address of the reward token
    function removeBoosterReward(address _booster, address token) external onlyOwner {
        IBooster(_booster).removeStaleToken(token);
    }

    /// @notice update the reward duration of a reward token
    /// @param _booster address of the booster
    /// @param _token address of the reward token
    /// @param _duration duration of the reward distribution
    function updateBoosterRewardDuration(address _booster, address _token, uint256 _duration) external onlyOwner {
        IBooster(_booster).updateRewardDuration(_token, _duration);
    }

    /// @notice updates who can compound a Booster rewards
    /// @param _booster address of the booster
    /// @param _compounder address of the compounder
    function updateBoosterCompounder(address _booster, address _compounder) external onlyOwner {
        boosterInfo[_booster].compounder = _compounder;
    }

    /// @notice switch the mode of a booster, true = compounding, false = claiming
    /// @param _booster address of the booster
    /// @param _mode true = compounding, false = claiming
    function swithBoosterMode(address _booster, bool _mode) external {
        Info memory info = boosterInfo[_booster];
        if (msg.sender != info.compounder) revert InvalidCompounder();
        boosterInfo[_booster].compounding = _mode;
    }

    /// @notice updates the base reward params used when creating boosters
    /// @param _baseMinRewardAmount the new base min reward amount
    /// @param _basePeriodDuration the new base period duration
    function updateBaseRewardParams(uint256 _baseMinRewardAmount, uint256 _basePeriodDuration) external onlyOwner {
        baseMinRewardAmount = _baseMinRewardAmount;
        basePeriodDuration = _basePeriodDuration;
    }
}