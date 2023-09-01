// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";

/*
Note: Unexercised oROG will remain to be emitted and reinjected in the emissions schedule until the end of the emissions schedule
TODO: need an emission schedule
TODO: getMintAmount should check for MAX_SUPPLY and have an emission decrease mechanism
*/

contract Base is OFT {

    error NotBroker();
    error InvalidEmissionsParameters();

    /// @notice emitted when the emissions parameters are updated
    event EmissionsParametersUpdated(
        uint256 mintMultiplier, 
        uint256 stakerMultiplier, 
        uint256 stabilityMultiplier, 
        uint256 rogMultiplier
    );

    struct EmissionParams {
        /// @notice the multiplier MAV/ROG mints
        uint256 mintMultiplier;
        /// @notice the multiplier for rMAV stakers
        uint256 stakerMultiplier;
        /// @notice the multiplier for rMAV/MAV
        uint256 stabilityMultiplier;
        /// @notice the multiplier for ROG/ETH vault
        uint256 rogMultiplier;
    }
    
    /// @notice max supply of ROG
    uint256 public immutable MAX_SUPPLY;

    /// @notice the Broker contract
    address public immutable broker;

    /// @notice the current emissions parameters
    EmissionParams public emissionParams;

    /// @notice 100% in basis points
    uint256 public constant ONE = 1e18;

    /// @param _broker address of oROG
    /// @param _maxSupply max supply of ROG
    /// @param _lzEndpoint address of the layer zero endpoint
    /// @param _mintTo address to mint to
    constructor(
        address _broker,
        uint256 _maxSupply,
        address _lzEndpoint,
        address _mintTo
    ) OFT("Rogue Token", "ROG", _lzEndpoint) {

        broker = _broker;
        MAX_SUPPLY = _maxSupply;

        if (_mintTo != address(0)) {
            _mint(_mintTo, _maxSupply);
        }

        emissionParams.mintMultiplier = ONE;
        emissionParams.stakerMultiplier = ONE;
        emissionParams.stabilityMultiplier = ONE;
        emissionParams.rogMultiplier = ONE;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Modifiers ///////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice only the oROG (Broker) can call this function
    modifier onlyBroker() {
        if (msg.sender != broker) revert NotBroker();
        _;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Views ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function getMintAmount(uint256 mavAmount) external view returns (uint256) {
        return mavAmount * emissionParams.mintMultiplier / ONE;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Mint/Burn ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function mint(address to, uint256 amount) external onlyBroker {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Restricted ///////////////////////////
    ////////////////////////////////////////////////////////////////

    function setEmissionsParameters(
        uint256 _mintMultiplier,
        uint256 _stakerMultiplier,
        uint256 _stabilityMultiplier,
        uint256 _rogMultiplier
    ) external onlyOwner {

        if (
            _mintMultiplier == 0 || 
            _stakerMultiplier == 0 || 
            _stabilityMultiplier == 0 || 
            _rogMultiplier == 0
            ) revert InvalidEmissionsParameters();
            
        emissionParams.mintMultiplier = _mintMultiplier;
        emissionParams.stakerMultiplier = _stakerMultiplier;
        emissionParams.stabilityMultiplier = _stabilityMultiplier;
        emissionParams.rogMultiplier = _rogMultiplier;

        emit EmissionsParametersUpdated(
            _mintMultiplier,
            _stakerMultiplier,
            _stabilityMultiplier,
            _rogMultiplier
        );
    }
}