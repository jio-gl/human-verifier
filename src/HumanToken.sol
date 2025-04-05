// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title HumanToken
 * @dev ERC20 token awarded to users who pass the human verification
 */
contract HumanToken is ERC20, AccessControl {
    // Role for minters (e.g., HumanVerifier contract)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Amount to reward for passing verification
    uint256 public constant VERIFICATION_REWARD = 10 * 10**18; // 10 HUMAN tokens with 18 decimals
    
    // Cap on total supply
    uint256 public immutable cap;
    
    // Events
    event VerificationRewarded(address indexed user, uint256 amount);
    
    /**
     * @dev Constructor
     * @param initialSupply Initial token supply for the admin
     * @param supplyCap Maximum total supply
     */
    constructor(uint256 initialSupply, uint256 supplyCap) ERC20("Human Token", "HUMAN") {
        require(supplyCap > 0, "Supply cap must be greater than 0");
        require(initialSupply <= supplyCap, "Initial supply exceeds cap");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        _mint(msg.sender, initialSupply);
        cap = supplyCap;
    }
    
    /**
     * @dev Rewards a user with tokens for passing verification
     * @param to Address to reward
     */
    function rewardVerification(address to) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + VERIFICATION_REWARD <= cap, "Reward would exceed cap");
        
        _mint(to, VERIFICATION_REWARD);
        
        emit VerificationRewarded(to, VERIFICATION_REWARD);
    }
    
    /**
     * @dev Required override for AccessControl + ERC20
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC20).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}