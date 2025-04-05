// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPuzzleManager.sol";

/**
 * @title PuzzleManager
 * @dev Manages the creation, storage, and access to visual puzzles
 */
contract PuzzleManager is IPuzzleManager, Ownable {
    // Structure to store a puzzle
    struct Puzzle {
        uint256 x; // X coordinate of the solution (1-20)
        uint256 y; // Y coordinate of the solution (1-20)
        uint256 salt; // Salt to generate the puzzle
        address creator; // Creator of the puzzle
        bool active; // If the puzzle is active or has been consumed
    }
    
    // Array to store all puzzles
    Puzzle[] private puzzles;
    
    // Mapping of solution hash to puzzle ID to avoid duplicates
    mapping(bytes32 => bool) private puzzleExists;
    
    // Addresses authorized to add puzzles
    mapping(address => bool) public authorizedAddresses;
    
    // Events
    event PuzzleAdded(uint256 indexed puzzleId, address indexed creator);
    event PuzzleDeactivated(uint256 indexed puzzleId);
    event AuthorizationChanged(address indexed addr, bool authorized);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        authorizedAddresses[msg.sender] = true;
    }
    
    /**
     * @dev Adds a new puzzle to the system
     * @param x X coordinate of the solution (1-20)
     * @param y Y coordinate of the solution (1-20)
     * @param salt Salt to generate the puzzle
     * @param creator Creator of the puzzle
     * @return ID of the created puzzle
     */
    function addPuzzle(
        uint256 x,
        uint256 y,
        uint256 salt,
        address creator
    ) external override returns (uint256) {
        require(authorizedAddresses[msg.sender], "Not authorized");
        require(x > 0 && x <= 20, "X coordinate out of range");
        require(y > 0 && y <= 20, "Y coordinate out of range");
        
        // Generate unique hash to check for duplicates
        bytes32 solutionHash = keccak256(abi.encodePacked(x, y, salt));
        require(!puzzleExists[solutionHash], "Puzzle already exists");
        
        // Create and store the puzzle
        Puzzle memory newPuzzle = Puzzle({
            x: x,
            y: y,
            salt: salt,
            creator: creator,
            active: true
        });
        
        puzzles.push(newPuzzle);
        uint256 puzzleId = puzzles.length - 1;
        puzzleExists[solutionHash] = true;
        
        emit PuzzleAdded(puzzleId, creator);
        return puzzleId;
    }
    
    /**
     * @dev Adds multiple puzzles to the system (for bootstrapping)
     * @param solutions Array of solutions [x, y, salt]
     */
    function batchAddPuzzles(uint256[3][] calldata solutions) external {
        require(authorizedAddresses[msg.sender], "Not authorized");
        
        for (uint256 i = 0; i < solutions.length; i++) {
            uint256 x = solutions[i][0];
            uint256 y = solutions[i][1];
            uint256 salt = solutions[i][2];
            
            require(x > 0 && x <= 20, "X coordinate out of range");
            require(y > 0 && y <= 20, "Y coordinate out of range");
            
            // Generate unique hash to check for duplicates
            bytes32 solutionHash = keccak256(abi.encodePacked(x, y, salt));
            
            if (!puzzleExists[solutionHash]) {
                // Create and store the puzzle
                Puzzle memory newPuzzle = Puzzle({
                    x: x,
                    y: y,
                    salt: salt,
                    creator: msg.sender,
                    active: true
                });
                
                puzzles.push(newPuzzle);
                uint256 puzzleId = puzzles.length - 1;
                puzzleExists[solutionHash] = true;
                
                emit PuzzleAdded(puzzleId, msg.sender);
            }
        }
    }
    
    /**
     * @dev Deactivates a puzzle (when it has been consumed)
     * @param puzzleId ID of the puzzle to deactivate
     */
    function deactivatePuzzle(uint256 puzzleId) external override {
        require(authorizedAddresses[msg.sender], "Not authorized");
        require(puzzleId < puzzles.length, "Puzzle does not exist");
        
        puzzles[puzzleId].active = false;
        emit PuzzleDeactivated(puzzleId);
    }
    
    /**
     * @dev Gets the total number of puzzles
     * @return Total number of puzzles
     */
    function getPuzzleCount() external view override returns (uint256) {
        return puzzles.length;
    }
    
    /**
     * @dev Gets the ID of a puzzle by its index
     * @param index Index of the puzzle
     * @return ID of the puzzle
     */
    function getPuzzleIdByIndex(uint256 index) external view override returns (uint256) {
        require(index < puzzles.length, "Index out of bounds");
        return index;
    }
    
    /**
     * @dev Gets information about a puzzle by its ID
     * @param puzzleId ID of the puzzle
     * @return x X coordinate
     * @return y Y coordinate
     * @return salt Salt
     * @return creator Creator
     * @return active If it's active
     */
    function getPuzzle(uint256 puzzleId) external view override returns (
        uint256 x,
        uint256 y,
        uint256 salt,
        address creator,
        bool active
    ) {
        require(puzzleId < puzzles.length, "Puzzle does not exist");
        Puzzle storage puzzle = puzzles[puzzleId];
        return (puzzle.x, puzzle.y, puzzle.salt, puzzle.creator, puzzle.active);
    }
    
    /**
     * @dev Checks if a puzzle is active
     * @param puzzleId ID of the puzzle
     * @return If the puzzle is active
     */
    function isPuzzleActive(uint256 puzzleId) external view override returns (bool) {
        require(puzzleId < puzzles.length, "Puzzle does not exist");
        return puzzles[puzzleId].active;
    }
    
    /**
     * @dev Sets the authorization of an address to add puzzles
     * @param addr Address to authorize/deauthorize
     * @param authorized If the address is authorized
     */
    function setAuthorization(address addr, bool authorized) external onlyOwner {
        authorizedAddresses[addr] = authorized;
        emit AuthorizationChanged(addr, authorized);
    }
}