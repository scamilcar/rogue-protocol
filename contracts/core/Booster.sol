// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@ERC4626/src/xERC4626.sol";

import {IReward} from "@maverick/interfaces/IReward.sol";
import {IPoolPositionSlim} from "@maverick/interfaces/IPoolPositionSlim.sol";

import {Rewarder} from "contracts/core/base/Rewarder.sol";
import {IBoard} from "contracts/periphery/interfaces/IBoard.sol";

/*
TODO: mint oROG nft when claiming optionToken
TODO: events
*/

contract Booster is xERC4626, Rewarder {
    using SafeTransferLib for ERC20;
    using SafeCastLib for *; 

    /// @notice the address of the broker
    address public immutable broker;

    /// @notice the associated lp contract 
    address public immutable lpReward;

    /// @notice the address of the board
    address public immutable board;

    /// @param _poolPosition the associated pool position contract
    /// @param _lpReward the associated lp contract
    /// @param _broker the virtual option token distributed for liquidity mining
    /// @param _board the address of the board
    /// @param _manager the address of the owner of the booster
    /// @param name_ the name of the booster
    /// @param symbol_ the symbol of the booster
    constructor(
        address _poolPosition,
        address _lpReward,
        address _broker,
        address _board,
        address _manager,
        string memory name_,
        string memory symbol_)

        ERC4626(ERC20(_poolPosition), name_, symbol_)
        xERC4626(7 days)
        Rewarder(_manager) { 

        lpReward = _lpReward;
        broker = _broker;
        board = _board;

        ERC20(_poolPosition).approve(lpReward, type(uint256).max);
    }
    
    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into the Booster contract and mints shares in return.
     * @param assets The amount of assets to deposit.
     * @param receiver The address that will receive the shares.
     * @return shares The amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets, shares, receiver);
    }

    /**
     * @notice Mints shares in return for assets already in the Booster contract.
     * @param shares The amount of shares to mint.
     * @param receiver The address that will receive the shares.
     * @return assets The amount of assets transferred from the Booster contract.
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets, shares, receiver);
    }

    /**
     * @notice Withdraws assets from the Booster contract and burns shares.
     * @param assets The amount of assets to withdraw.
     * @param receiver The address that will receive the assets.
     * @param owner The address that owns the shares.
     * @return shares The amount of shares burned.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _beforeWithdraw(assets, shares, owner, receiver);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Redeems shares in return for assets already in the Booster contract.
     * @param shares The amount of shares to redeem.
     * @param receiver The address that will receive the assets.
     * @param owner The address that owns the shares.
     * @return assets The amount of assets transferred from the Booster contract.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _beforeWithdraw(assets, shares, owner, receiver);
        
        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // Update storedTotalAssets on deposit/mint
    function _afterDeposit(uint256 assets, uint256 shares, address receiver) internal {
        _stake(shares, receiver);
        IReward(lpReward).stake(assets, board);
        super.afterDeposit(assets, shares);

    }

    // Update storedTotalAssets on withdraw/redeem
    function _beforeWithdraw(uint256 assets, uint256 shares, address owner, address receiver) internal {
        super.beforeWithdraw(assets, shares);
        _unstake(shares, owner);
        IBoard(board).unstake(lpReward, assets, receiver);
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeems shares in return for assets already in the Booster contract.
     * @param to The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        _unstake(amount, msg.sender);
        _stake(amount, to);
        return true;
    }

    /**
     * @notice Redeems shares in return for assets already in the Booster contract.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool){
        super.transferFrom(from, to, amount);
        _unstake(amount, from);
        _stake(amount, to);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             REWARD LOGIC
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice get caller's rewards for a list of reward token index
     * @param recipient address to receive the rewards
     * @param rewardTokenIndices list of reward token index
     */
    function getReward(address recipient, uint8[] calldata rewardTokenIndices) external {
        _getReward(msg.sender, recipient, rewardTokenIndices);
    }

    /**
     * @notice get caller's rewards for a single reward token index
     * @param recipient address to receive the rewards
     * @param rewardTokenIndex reward token index
     */
    function getReward(address recipient, uint8 rewardTokenIndex) external returns (uint256) {
        return _getReward(msg.sender, recipient, rewardTokenIndex);
    }

    /*//////////////////////////////////////////////////////////////
                             xERC4626 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compute the amount of assets available to mint shares.
     */
    function syncRewards() public override {
        uint192 lastRewardAmount_ = lastRewardAmount;
        uint32 timestamp = block.timestamp.safeCastTo32();

        if (timestamp < rewardsCycleEnd) revert SyncError();

        uint256 storedTotalAssets_ = storedTotalAssets;
        /// @dev Board has the asset balance
        uint256 nextRewards = asset.balanceOf(board) - storedTotalAssets_ - lastRewardAmount_;

        storedTotalAssets = storedTotalAssets_ + lastRewardAmount_; // SSTORE

        uint32 end = ((timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength;

        // Combined single SSTORE
        lastRewardAmount = nextRewards.safeCastTo192();
        lastSync = timestamp;
        rewardsCycleEnd = end;

        emit NewRewardsCycle(end, nextRewards);
    }
}