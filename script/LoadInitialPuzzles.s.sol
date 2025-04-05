// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/PuzzleManager.sol";

/**
 * @title LoadInitialPuzzlesScript
 * @dev Script to load initial puzzles into the system
 */
contract LoadInitialPuzzlesScript is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_KEY");
        address puzzleManagerAddress = vm.envAddress("PUZZLE_MANAGER_ADDRESS");
        
        // Load puzzles from a JSON file
        string memory puzzlesJson = vm.readFile("./data/initial_puzzles.json");
        bytes memory puzzlesData = vm.parseJson(puzzlesJson);
        
        // Decode the JSON into a usable structure
        // Expected JSON structure:
        // [
        //   [x1, y1, salt1],
        //   [x2, y2, salt2],
        //   ...
        // ]
        uint256[][3][] memory puzzlesRaw = abi.decode(puzzlesData, (uint256[][3][]));
        
        // Convert to format expected by the contract
        uint256 totalPuzzles = puzzlesRaw.length;
        console.log("Loading", totalPuzzles, "initial puzzles...");
        
        uint256[3][] memory puzzlesToLoad = new uint256[3][](totalPuzzles);
        for (uint256 i = 0; i < totalPuzzles; i++) {
            puzzlesToLoad[i][0] = puzzlesRaw[i][0][0]; // x
            puzzlesToLoad[i][1] = puzzlesRaw[i][1][0]; // y
            puzzlesToLoad[i][2] = puzzlesRaw[i][2][0]; // salt
        }
        
        vm.startBroadcast(adminPrivateKey);
        
        PuzzleManager puzzleManager = PuzzleManager(puzzleManagerAddress);
        
        // Load puzzles in batches to optimize gas
        uint256 batchSize = 50;
        uint256 batches = (totalPuzzles + batchSize - 1) / batchSize; // Round up
        
        for (uint256 batch = 0; batch < batches; batch++) {
            uint256 startIdx = batch * batchSize;
            uint256 endIdx = startIdx + batchSize;
            if (endIdx > totalPuzzles) {
                endIdx = totalPuzzles;
            }
            
            uint256 batchLength = endIdx - startIdx;
            uint256[3][] memory batchPuzzles = new uint256[3][](batchLength);
            
            for (uint256 j = 0; j < batchLength; j++) {
                batchPuzzles[j] = puzzlesToLoad[startIdx + j];
            }
            
            console.log("Loading batch", batch + 1, "of", batches, "(", batchLength, "puzzles)");
            puzzleManager.batchAddPuzzles(batchPuzzles);
        }
        
        vm.stopBroadcast();
        
        console.log("Puzzle loading completed!");
        console.log("Total puzzles loaded:", totalPuzzles);
    }
    
    /**
     * @dev Helper function to generate test data
     * This function can be used by external scripts to create initial puzzles
     */
    function generateSamplePuzzles(uint256 count) public pure returns (uint256[3][] memory) {
        uint256[3][] memory puzzles = new uint256[3][](count);
        
        for (uint256 i = 0; i < count; i++) {
            // Generate random coordinates between 1 and 20
            uint256 x = (i % 20) + 1;
            uint256 y = ((i / 20) % 20) + 1;
            
            // Use a salt based on the index, but with some randomness
            uint256 salt = uint256(keccak256(abi.encodePacked(i, x, y)));
            
            puzzles[i][0] = x;
            puzzles[i][1] = y;
            puzzles[i][2] = salt;
        }
        
        return puzzles;
    }
}