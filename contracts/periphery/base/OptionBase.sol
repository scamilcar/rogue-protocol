// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IReward} from "@maverick/interfaces/IReward.sol";

import {IBase} from "contracts/periphery/interfaces/IBase.sol";
import {IOracle} from "contracts/periphery/interfaces/IOracle.sol";
import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";
import {IManager} from "contracts/core//interfaces/IManager.sol";
import {IBooster} from "contracts/core/interfaces/IBooster.sol";
import {ILocker} from "contracts/core/interfaces/ILocker.sol";
import {IStaker} from "contracts/core/interfaces/IStaker.sol";
import {IEscrow} from "contracts/periphery/interfaces/IEscrow.sol";

// /*
// TODO: Need svg for the art
// */

abstract contract OptionBase is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error NotEarningsManager();
    error InvalidQuoteToken(address token);
    error AlreadyQuoteToken(address token);
    error NotVaultManager();
    error InvalidMinter();
    error NotAuthorized(address caller, uint256 id);
    error OptionExpired(uint expiry);
    error InvalidDiscountValues();
    error DiscountTooHigh();

    event DiscountIntervalUpdated(uint256 minActivityDiscount, uint256 maxActivityDiscount);
    event DiscountModeSet(bool manualLockupDiscount, bool manualLpDiscount);
    event BoardUpdated(address board);
    event Exercised(
        address indexed to,
        uint256 id,
        address indexed quoteToken,
        uint256 quoteTokenAmount,
        uint256 amount,
        uint256 discount
    );
    event ManualDiscountsUpdated(uint256 lockupDiscount, uint256 lpDiscount);
    event PeriodDurationUpdated(uint256 periodDuration);
    event QuoteTokenAdded(address quoteToken, address oracle);
    event QuoteTokenOracleModified(address quoteToken, address oracle);
    event QuoteTokenRemoved(address quoteToken);
    event QuoteTokensCollected(address quoteToken, uint256 amount);

    struct Option {
        uint256 amount;
        uint256 discount;
        uint256 expiry;
    }

    struct Params {
        bool lockupMode;
        bool lpMode;
        uint256 minActivityDiscount;
        uint256 maxActivityDiscount;
        uint256 manualLockupDiscount;
        uint256 manualLpDiscount;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// State ///////////////////////////
    ////////////////////////////////////////////////////////////////

    address public mav;
    address public veMav;
    address public base;
    address public manager;
    address public board;
    address public locker;
    address public staker;
    address public escrow;
    uint256 public periodDuration;
    uint256 public constant ONE = 1e18;

    Params public params;
    mapping(uint256 id => Option option) public options;
    mapping (address => address) public oracles;

    /// @notice the quote tokens that can be used to exercise the call option
    EnumerableSet.AddressSet private _quoteTokens;

    ////////////////////////////////////////////////////////////////
    ///////////////////////// Constructor //////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @param _veMav veMav contract
    /// @param _mav mav contract
    /// @param _periodDuration the expiry of the call option
    constructor(
        address _veMav,
        address _mav,
        uint256 _periodDuration
    ) ERC721Enumerable() {
        veMav = _veMav;
        mav = _mav;
        periodDuration = _periodDuration;
    }

    /// @notice only vaults allowed to call
    modifier onlyMinter() {
        if (msg.sender != staker && !IManager(manager).isBooster(msg.sender)) 
            revert InvalidMinter();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Views /////////////////////////////
    ////////////////////////////////////////////////////////////////
    
    function idsOfOwner(address account) public view returns (uint256[] memory) {
        uint256 length = balanceOf(account);
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            ids[i] = tokenOfOwnerByIndex(account, i);
        }
        return ids;
    }

    function quoteTokenAt(uint256 index) external view returns (address) {
        return _quoteTokens.at(index);
    }

    function quoteTokensLength() external view returns (uint256) {
        return _quoteTokens.length();
    }

    function isQuoteToken(address _token) external view returns (bool) {
        return _quoteTokens.contains(_token);
    }

    function quoteTokens() external view returns (address[] memory) {
        return _quoteTokens.values();
    }

    function getQuoteTokenAmount(address _quoteToken, uint256 _amount, uint256 _discount) public view returns (uint256) {
        uint256 price = getPrice(_quoteToken);
        uint256 discountedPrice = price * (ONE - _discount) / ONE;
        return _amount * discountedPrice / ONE; // unscale since discount is scaled
    }

    function getPrice(address quoteToken) public view returns (uint256 rogPrice) {
        rogPrice = IOracle(oracles[quoteToken]).price();
    }

    function getLockupDiscount() public view returns(uint256) {
        if (params.lockupMode) {
            return params.manualLockupDiscount;
        } else {
            return getActivityDiscount(ILocker(locker).totalLocked(), IERC20(mav).balanceOf(veMav));
        }
    }

    function getProvisionDiscount(address _booster) public view returns(uint256) {
        if (params.lpMode) {
            return params.manualLpDiscount;
        } else {
            IBooster booster = IBooster(_booster);
            address lpReward = address(booster.lpReward());
            return getActivityDiscount(booster.totalSupply(), IERC20(lpReward).totalSupply());
        }
    }

    function getActivityDiscount(uint256 numerator, uint256 denominator) public view returns (uint256) {
        uint256 activity = numerator * ONE / denominator;
        return params.minActivityDiscount + (ONE - activity) * (params.maxActivityDiscount - params.minActivityDiscount) / ONE;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////// Exercise ////////////////////////
    ////////////////////////////////////////////////////////////////

    function exercise(uint256 _id, address _to, address _quoteToken, bool _lock, uint256 _duration) external nonReentrant {
        Option memory option = options[_id];

        if (!_isApprovedOrOwner(msg.sender, _id)) revert NotAuthorized(msg.sender, _id);
        if (block.timestamp > option.expiry) revert OptionExpired(option.expiry);
        if (!_quoteTokens.contains(_quoteToken)) revert InvalidQuoteToken(_quoteToken);

        _burn(_id);
        uint256 quoteTokenAmount = getQuoteTokenAmount(_quoteToken, option.amount, option.discount);
        
        IERC20(_quoteToken).transferFrom(msg.sender, address(this), quoteTokenAmount);

        if (_lock) {
            IBase(base).mint(address(this), option.amount);
            IERC20(base).approve(escrow, option.amount);
            IEscrow(escrow).stake(option.amount, _duration, _to);
        } else {
            IBase(base).mint(_to, option.amount);
        }
        
        emit Exercised(_to, _id, _quoteToken, quoteTokenAmount, option.amount, option.discount);
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// Restricted //////////////////////////
    ////////////////////////////////////////////////////////////////

    function collectQuoteTokens() external {
        for (uint256 i = 0; i < _quoteTokens.length(); i++) {
            address _quoteToken = _quoteTokens.at(i);
            uint256 balance = IERC20(_quoteToken).balanceOf(address(this));
            IERC20(_quoteToken).approve(board, balance); // approve earnings manager to collect quote tokens (if needed
            IBoard(board).notifyBrokerFees(_quoteToken, balance);
            emit QuoteTokensCollected(_quoteToken, balance);
        }
    }

    function addQuoteToken(address _token, address _oracle) external onlyOwner {
        if (_quoteTokens.contains(_token)) revert AlreadyQuoteToken(_token);
        _quoteTokens.add(_token);
        oracles[_token] = _oracle;
        IERC20(_token).safeApprove(board, type(uint256).max);
        emit QuoteTokenAdded(_token, _oracle);
    }

    function removeQuoteToken(address _token) external onlyOwner {
        if (!_quoteTokens.contains(_token)) revert InvalidQuoteToken(_token);
        _quoteTokens.remove(_token);
        delete oracles[_token];
        emit QuoteTokenRemoved(_token);
    }

    function modifyQuoteTokenOracle(address _token, address _oracle) external onlyOwner {
        if (!_quoteTokens.contains(_token)) revert InvalidQuoteToken(_token);
        oracles[_token] = _oracle;
        emit QuoteTokenOracleModified(_token, _oracle);
    }

    function setPeriodDuration(uint256 _periodDuration) external onlyOwner {
        periodDuration = _periodDuration;
        emit PeriodDurationUpdated(_periodDuration);
    }

    function setDiscountMode(bool _lockupDiscountMode, bool _lpDiscountMode) external onlyOwner {
        params.lockupMode = _lockupDiscountMode;
        params.lpMode = _lpDiscountMode;
        emit DiscountModeSet(_lockupDiscountMode, _lpDiscountMode);
    }

    function updateDiscountInterval(uint256 _minDiscount, uint256 _maxDiscount) external onlyOwner {
        if (_minDiscount > 0) {
            if (_minDiscount >= _maxDiscount) revert InvalidDiscountValues();
            if (_minDiscount >= ONE - 1 || _maxDiscount >= ONE) revert DiscountTooHigh();
        }
        params.minActivityDiscount = _minDiscount;
        params.maxActivityDiscount = _maxDiscount;
        emit DiscountIntervalUpdated(_minDiscount, _maxDiscount);
    }

    function updateManualDiscounts(uint256 _lockupDiscount, uint256 _lpDiscount) external onlyOwner {
        if (_lockupDiscount >= ONE - 1 || _lpDiscount >= ONE - 1) revert DiscountTooHigh();
        params.manualLockupDiscount = _lockupDiscount;
        params.manualLpDiscount = _lpDiscount;
        emit ManualDiscountsUpdated(_lockupDiscount, _lpDiscount);
    }

    function setEarningsManager(address _board) external onlyOwner {
        board = _board;
        emit BoardUpdated(_board);
    }
}

