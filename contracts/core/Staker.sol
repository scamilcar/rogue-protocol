// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/core/base/Votes.sol";

import "@ERC4626/src/xERC4626.sol";

import {Rewarder} from "contracts/core/base/Rewarder.sol";

contract Staker is Votes, xERC4626, Rewarder {
    using SafeTransferLib for ERC20;
    using SafeCastLib for *; 

    error VoteSupplyExceeded();

    /// @notice address of the Broker
    address public immutable broker;

    /// @param _stakingToken address of staking token
    /// @param _owner address of owner
    constructor(ERC20 _stakingToken, address _broker, address _owner)
        ERC4626(_stakingToken, "Staked rMAV", "srMAV")
        xERC4626(7 days)
        Rewarder(_owner) {
        
        broker = _broker;
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

        _beforeWithdraw(assets, shares, owner);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
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

        _beforeWithdraw(assets, shares, owner);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    // Update storedTotalAssets on deposit/mint
    function _afterDeposit(uint256 assets, uint256 shares, address receiver) internal {
        _stake(shares, receiver);
        _transferVotingUnits(address(0), receiver, assets);
        _delegate(receiver, receiver);
        super.afterDeposit(assets, shares);
    }

    // Update storedTotalAssets on withdraw/redeem
    function _beforeWithdraw(uint256 assets, uint256 shares, address owner) internal {
        super.beforeWithdraw(assets, shares);
        _unstake(shares, owner);
        _transferVotingUnits(owner, address(0), assets);
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
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer shares from `msg.sender` to `to`.
     * @param to The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        _unstake(amount, msg.sender);
        _stake(amount, to);
        _transferVotingUnits(msg.sender, to, amount);
        _delegate(to, to);
        return true;
    }

    /**
     * @notice Transfer shares from `from` to `to`.
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
        _transferVotingUnits(from, to, amount);
        _delegate(to, to);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             VOTE/DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Votes override, return the amount of voting units for `account`
    function _getVotingUnits(address account) internal view override returns (uint256) {
        return stakeOf[account];
    }

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function delegateBySig(
        address owner,
        address delegatee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= deadline, "Votes: signature expired");
        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01", 
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Delegation(address owner,address delegatee,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            delegatee,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );
        require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");
        _delegate(recoveredAddress, delegatee);
    }
}