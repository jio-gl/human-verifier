// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/HumanVerifier.sol";

/**
 * @title ConfigureScript
 * @dev Script to configure the HumanVerifier system after deployment
 */
contract ConfigureScript is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_KEY");
        address humanVerifierAddress = vm.envAddress("HUMAN_VERIFIER_ADDRESS");
        
        // Load configuration parameters from environment
        uint256 totalPuzzles = vm.envOr("TOTAL_PUZZLES", uint256(35));
        uint256 newPuzzlesRequired = vm.envOr("NEW_PUZZLES_REQUIRED", uint256(5));
        uint256 minCorrectPuzzles = vm.envOr("MIN_CORRECT_PUZZLES", uint256(27));
        uint256 maxAttempts = vm.envOr("MAX_ATTEMPTS", uint256(3));
        uint256 puzzleConsumptionThreshold = vm.envOr("PUZZLE_CONSUMPTION_THRESHOLD", uint256(8));
        
        console.log("Configuring HumanVerifier at:", humanVerifierAddress);
        console.log("Parameters:");
        console.log("  Total puzzles:           ", totalPuzzles);
        console.log("  New puzzles required:    ", newPuzzlesRequired);
        console.log("  Min correct puzzles:     ", minCorrectPuzzles);
        console.log("  Max attempts:            ", maxAttempts);
        console.log("  Puzzle consumption:      ", puzzleConsumptionThreshold);
        
        vm.startBroadcast(adminPrivateKey);
        
        HumanVerifier humanVerifier = HumanVerifier(humanVerifierAddress);
        
        // Update configuration
        humanVerifier.configure(
            totalPuzzles,
            newPuzzlesRequired,
            minCorrectPuzzles,
            maxAttempts,
            puzzleConsumptionThreshold
        );
        
        // If a new genesis hash is needed, uncomment and configure this
        // bytes32 newGenesisHash = keccak256(abi.encodePacked(block.timestamp, "NEW_SEED"));
        // humanVerifier.updateGenesisHash(newGenesisHash);
        // console.log("Genesis hash updated to:", vm.toString(newGenesisHash));
        
        vm.stopBroadcast();
        
        console.log("Configuration completed successfully.");
    }
}