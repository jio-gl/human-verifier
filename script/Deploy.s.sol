// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/PuzzleManager.sol";
import "../src/HumanVerifier.sol";
import "../src/ZKPVerifier.sol"; // Contract generated by Circom/snarkjs
import "../src/VerifiedHumanNFT.sol";
import "../src/HumanToken.sol";

/**
 * @title DeployScript
 * @dev Deployment script for the HumanVerifier system
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the puzzle manager
        PuzzleManager puzzleManager = new PuzzleManager();
        console.log("PuzzleManager deployed at:", address(puzzleManager));
        
        // Deploy the ZKP verifier (generated by snarkjs)
        Groth16Verifier zkpVerifier = new Groth16Verifier();
        console.log("ZKPVerifier deployed at:", address(zkpVerifier));
        
        // Generate genesis hash for the system
        bytes32 genesisHash = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)));
        console.log("System genesis hash:", vm.toString(genesisHash));
        
        // Deploy the NFT and token
        string memory baseURI = "https://humanverifier.io/metadata/";
        VerifiedHumanNFT verifiedHumanNFT = new VerifiedHumanNFT(baseURI);
        console.log("VerifiedHumanNFT deployed at:", address(verifiedHumanNFT));
        
        uint256 initialSupply = 1000000 * 10**18; // 1 million tokens
        uint256 supplyCap = 100000000 * 10**18; // 100 million tokens
        HumanToken humanToken = new HumanToken(initialSupply, supplyCap);
        console.log("HumanToken deployed at:", address(humanToken));
        
        // Deploy the human verifier
        HumanVerifier humanVerifier = new HumanVerifier(
            genesisHash,
            address(zkpVerifier),
            address(puzzleManager),
            address(verifiedHumanNFT),
            address(humanToken)
        );
        console.log("HumanVerifier deployed at:", address(humanVerifier));
        
        // Configure authorizations in the puzzle manager
        puzzleManager.setAuthorization(address(humanVerifier), true);
        console.log("Authorization configured: HumanVerifier can manage puzzles");
        
        // Grant MINTER_ROLE to HumanVerifier in NFT and token contracts
        verifiedHumanNFT.grantRole(verifiedHumanNFT.MINTER_ROLE(), address(humanVerifier));
        humanToken.grantRole(humanToken.MINTER_ROLE(), address(humanVerifier));
        console.log("HumanVerifier granted minting permissions");
        
        // Configure initial system parameters
        humanVerifier.configure(
            35, // totalPuzzles
            5,  // newPuzzlesRequired
            27, // minCorrectPuzzles
            3,  // maxAttempts
            8   // puzzleConsumptionThreshold
        );
        console.log("Initial parameters configured");
        
        vm.stopBroadcast();
        
        console.log("\n--- DEPLOYMENT SUMMARY ---");
        console.log("PuzzleManager:     ", address(puzzleManager));
        console.log("ZKPVerifier:       ", address(zkpVerifier));
        console.log("VerifiedHumanNFT:  ", address(verifiedHumanNFT));
        console.log("HumanToken:        ", address(humanToken));
        console.log("HumanVerifier:     ", address(humanVerifier));
        console.log("\nRemember to load initial puzzles by running:");
        console.log("forge script script/LoadInitialPuzzles.s.sol --rpc-url $RPC_URL --private-key $ADMIN_KEY --broadcast");
    }
}