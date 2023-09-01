// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {OptionBase} from "contracts/periphery/base/OptionBase.sol";
import {Claim} from "contracts/periphery/base/Claim.sol";
import {IClaim} from "contracts/periphery/interfaces/IClaim.sol";
import {IBase} from "contracts/periphery/interfaces/IBase.sol";
import {IRewarder} from "contracts/core/interfaces/IRewarder.sol";
import {IStaker} from "contracts/core/interfaces/IStaker.sol";

contract Broker is OptionBase {

    error AlreadyInitialized();
    error ZeroAddress();
    error NoEmissionsToDistribute();
    
    event EmissionsDistributed(uint256 rMavShare, uint256 stabilityShare, uint256 rogShare);
    event Initialized(address manager, address base, address staker, address escrow, address locker);
    event BoostersUpdated(address stabilityBooster, address rogBooster);

    /// @notice address of option claim token
    address public claimToken;

    /// @notice address of the stability booster
    address public stabilityBooster;

    /// @notice address of the base Booster
    address public rogBooster;

    /// @notice number of minted ROG by LPs
    uint public minted;

    /// @notice returns true if the contract is initialized
    bool public initialized;
    
    /// @notice the next option id that will be minted
    uint256 internal nextId;
    
    /// @param _veMav veMav address
    /// @param _mav mav address
    /// @param _periodDuration duration of the option
    constructor(
        address _veMav,
        address _mav,
        uint256 _periodDuration
    ) 
        OptionBase(_veMav, _mav, _periodDuration)
        ERC721("Rogue Broker", "Broker") {

        ++nextId;

        claimToken = address(new Claim());
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Mint ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice mint an option for an account
    /// @param to address of the account
    /// @param claimed amount of mav claimed
    function mint(address to, uint256 claimed) external onlyMinter {
        (uint _amount, uint _discount, uint _expiry) = msg.sender == staker ? 
            _getLockupOptionParameters(claimed) : 
            _getLPOptionParameters(claimed, msg.sender);
        if (_amount > 0) {
            uint256 _nextId = nextId;
            options[_nextId] = Option({
                amount: _amount,
                discount: _discount,
                expiry: _expiry
            });
            _mint(to, _nextId);
            ++nextId;
            minted += _amount;
        }
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Distribute ////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice distrbiute the emissions to the staker, stability and base vaults
    function distributeEmissions() external {
        if (minted == 0) revert NoEmissionsToDistribute();
        (uint stakerShare, uint stabilityShare, uint rogShare) = _getEmissionsShares(minted);
        uint tokensToMint = stakerShare + stabilityShare + rogShare;
        IClaim(claimToken).mint(address(this), tokensToMint);
        IRewarder(staker).notifyAndTransfer(claimToken, stakerShare);
        IRewarder(stabilityBooster).notifyAndTransfer(claimToken, stabilityShare);
        IRewarder(rogBooster).notifyAndTransfer(claimToken, rogShare);
        minted = 0;
        emit EmissionsDistributed(stakerShare, stabilityShare, rogShare);
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Internal ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice get the option parameters, the discount is based on platform and user usage
    /// @param _amount amount of mav to compute for
    /// @return amount of oROG to mint the option is eligible for
    /// @return discount the discount to ROG market price the option grants
    /// @return expiry the expiry of the option
    function _getLockupOptionParameters(uint _amount) internal view returns (uint amount, uint discount, uint expiry) {
        amount = IBase(base).getMintAmount(_amount); 
        discount = getLockupDiscount();
        expiry = block.timestamp + periodDuration;
    }

    /// @notice get the option parameters, the discount is based on platform and user usage
    /// @param _amount amount of mav to compute for
    /// @param _booster address of the booster
    /// @return amount of oROG to mint the option is eligible for
    /// @return discount the discount to ROG market price the option grants
    /// @return expiry the expiry of the option
    function _getLPOptionParameters(uint _amount, address _booster) internal view returns (uint amount, uint discount, uint expiry) {
        amount = IBase(base).getMintAmount(_amount);
        discount = getProvisionDiscount(_booster);
        expiry = block.timestamp + periodDuration;
    }

    /// @notice get mintable amount for rMAV stakers, rMAV/MAV and ROG/ETH vaults according to a amount of oROG
    /// @param _minted amount of ROG minted
    function _getEmissionsShares(uint _minted) internal view returns (uint stakerShare, uint stabilityShare, uint rogShare) {
        (, uint stakerMultiplier, uint stabilityMultiplier, uint rogMultiplier) = IBase(base).emissionParams();
        stakerShare = _minted * stakerMultiplier / ONE;
        stabilityShare = _minted * stabilityMultiplier / ONE;
        rogShare = _minted * rogMultiplier / ONE;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Restricted ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice initialize the contract
    /// @param _base base token address
    /// @param _staker staker address
    function initialize(
        address _manager, 
        address _base, 
        address _staker, 
        address _escrow,
        address _locker,
        address _board
    ) external onlyOwner {
        if (initialized) revert AlreadyInitialized();
        manager = _manager;
        base = _base;
        staker = _staker;
        escrow = _escrow;
        locker = _locker;
        board = _board;
        IERC20(claimToken).approve(address(_staker), type(uint256).max);
        initialized = true;
        emit Initialized(_manager, _base, _staker, _escrow, _locker);
    }

    /// @notice set the vaults addresses
    /// @param _stabilityBooster stability booster address
    /// @param _rogBooster base booster address
    function updateBoosters(address _stabilityBooster, address _rogBooster) external onlyOwner {
        stabilityBooster = _stabilityBooster;
        rogBooster = _rogBooster;
        IERC20(claimToken).approve(_stabilityBooster, type(uint256).max);
        IERC20(claimToken).approve(_rogBooster, type(uint256).max);
        emit BoostersUpdated(_stabilityBooster, _rogBooster);
    }
}