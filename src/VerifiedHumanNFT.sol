// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title VerifiedHumanNFT
 * @dev NFT awarded to users who pass the human verification
 */
contract VerifiedHumanNFT is ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    
    // Role for minters (e.g., HumanVerifier contract)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Token counter
    Counters.Counter private _tokenIdCounter;
    
    // Base URI for token metadata
    string private _baseTokenURI;
    
    // Mapping to track if an address already has a token
    mapping(address => bool) public hasToken;
    
    // Events
    event VerifiedHumanMinted(address indexed to, uint256 indexed tokenId);
    
    /**
     * @dev Constructor
     * @param baseURI Base URI for token metadata
     */
    constructor(string memory baseURI) ERC721("VerifiedHuman", "VHUMAN") {
        _baseTokenURI = baseURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mints a new VerifiedHuman NFT to the specified address
     * @param to Address to mint the token to
     * @return tokenId ID of the minted token
     */
    function mint(address to) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(!hasToken[to], "Address already has a VerifiedHuman NFT");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        hasToken[to] = true;
        
        emit VerifiedHumanMinted(to, tokenId);
        
        return tokenId;
    }
    
    /**
     * @dev Updates the base URI for token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }
    
    /**
     * @dev Returns the base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Required override for AccessControl + ERC721
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}