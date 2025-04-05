// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HumanVerifier.sol";
import "../src/PuzzleManager.sol";
import "../src/VerifiedHumanNFT.sol";
import "../src/HumanToken.sol";
import "../src/interfaces/IVerifier.sol";

contract MockVerifier is IVerifier {
    bool private returnValue;
    
    function setReturnValue(bool _returnValue) external {
        returnValue = _returnValue;
    }
    
    function verifyProof(bytes memory, uint256[] memory) external view override returns (bool) {
        return returnValue;
    }
}

contract HumanVerifierTest is Test {
    HumanVerifier public humanVerifier;
    PuzzleManager public puzzleManager;
    MockVerifier public mockVerifier;
    VerifiedHumanNFT public nft;
    HumanToken public token;
    
    bytes32 public genesisHash;
    address public admin = address(1);
    address public user = address(2);
    
    // User keys for signing
    uint256 public userPrivateKey = 0xA11CE;
    address public userWallet;
    
    // Test parameters
    uint256 public totalPuzzles = 35;
    uint256 public newPuzzlesRequired = 5;
    uint256 public minCorrectPuzzles = 27;
    uint256 public maxAttempts = 3;
    uint256 public puzzleConsumptionThreshold = 8;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Create genesis hash
        genesisHash = keccak256(abi.encodePacked("TEST_GENESIS", block.timestamp));
        
        // Deploy mock verifier
        mockVerifier = new MockVerifier();
        mockVerifier.setReturnValue(true); // Mock always returns valid proof
        
        // Deploy puzzle manager
        puzzleManager = new PuzzleManager();
        
        // Deploy NFT and token
        string memory baseURI = "https://test.humanverifier.io/metadata/";
        nft = new VerifiedHumanNFT(baseURI);
        
        uint256 initialSupply = 1000000 * 10**18; // 1 million tokens
        uint256 supplyCap = 100000000 * 10**18; // 100 million tokens
        token = new HumanToken(initialSupply, supplyCap);
        
        // Deploy human verifier
        humanVerifier = new HumanVerifier(
            genesisHash,
            address(mockVerifier),
            address(puzzleManager),
            address(nft),
            address(token)
        );
        
        // Configure system
        humanVerifier.configure(
            totalPuzzles,
            newPuzzlesRequired,
            minCorrectPuzzles,
            maxAttempts,
            puzzleConsumptionThreshold
        );
        
        // Authorize human verifier to add puzzles
        puzzleManager.setAuthorization(address(humanVerifier), true);
        
        // Grant roles to human verifier
        nft.grantRole(nft.MINTER_ROLE(), address(humanVerifier));
        token.grantRole(token.MINTER_ROLE(), address(humanVerifier));
        
        // Load initial puzzles
        loadInitialPuzzles(1000); // Load 1000 initial puzzles
        
        // Set up user wallet
        userWallet = vm.addr(userPrivateKey);
        
        // Reset user attempts
        humanVerifier.resetUserAttempts(userWallet);
        
        vm.stopPrank();
    }
    
    function testConfiguration() public {
        assertEq(humanVerifier.totalPuzzles(), totalPuzzles);
        assertEq(humanVerifier.newPuzzlesRequired(), newPuzzlesRequired);
        assertEq(humanVerifier.minCorrectPuzzles(), minCorrectPuzzles);
        assertEq(humanVerifier.maxAttempts(), maxAttempts);
        assertEq(humanVerifier.puzzleConsumptionThreshold(), puzzleConsumptionThreshold);
        assertEq(humanVerifier.genesisHash(), genesisHash);
    }
    
    function testRequestPuzzles() public {
        vm.startPrank(userWallet);
        
        // Generate signature for puzzle request
        uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Request puzzles
        humanVerifier.requestPuzzles(signature);
        
        // Check attempt number was incremented
        assertEq(humanVerifier.userAttemptNumber(userWallet), attemptNumber + 1);
        
        // Check puzzles were assigned
        assertEq(humanVerifier.assignedPuzzles(userWallet, 0) > 0, true);
        
        vm.stopPrank();
    }
    
    function testInvalidSignature() public {
        vm.startPrank(userWallet);
        
        // Generate invalid signature (wrong message)
        bytes32 wrongMessage = keccak256(abi.encodePacked("WRONG_MESSAGE"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, wrongMessage);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Expect revert on request with invalid signature
        vm.expectRevert("Invalid signature");
        humanVerifier.requestPuzzles(signature);
        
        vm.stopPrank();
    }
    
    function testVerificationSuccess() public {
        vm.startPrank(userWallet);
        
        // First request puzzles
        uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        humanVerifier.requestPuzzles(signature);
        
        // Check initial verification status
        assertEq(humanVerifier.isVerifiedHuman(userWallet), false);
        
        // Check initial NFT and token balances
        assertEq(nft.balanceOf(userWallet), 0);
        assertEq(token.balanceOf(userWallet), 0);
        
        // Set mock verifier to return true
        vm.stopPrank();
        vm.prank(admin);
        mockVerifier.setReturnValue(true);
        vm.startPrank(userWallet);
        
        // Prepare verification inputs
        bytes memory proof = abi.encodePacked("MOCK_PROOF");
        uint256[] memory publicInputs = new uint256[](totalPuzzles);
        
        // Fill with values to simulate all puzzles correct
        for (uint256 i = 0; i < totalPuzzles; i++) {
            publicInputs[i] = 1; // 1 means solved
        }
        
        // Prepare new puzzles
        uint256[3][] memory solutions = new uint256[3][](newPuzzlesRequired);
        for (uint256 i = 0; i < newPuzzlesRequired; i++) {
            solutions[i][0] = 10; // x
            solutions[i][1] = 10; // y
            solutions[i][2] = uint256(keccak256(abi.encodePacked("SALT", i))); // salt
        }
        
        // Submit verification
        humanVerifier.submitVerification(proof, publicInputs, solutions);
        
        // Check verification status
        assertEq(humanVerifier.isVerifiedHuman(userWallet), true);
        
        // Check NFT and token rewards
        assertEq(nft.balanceOf(userWallet), 1);
        assertEq(token.balanceOf(userWallet), 10 * 10**18); // 10 HUMAN tokens
        
        // Check that user is marked as having an NFT
        assertEq(nft.hasToken(userWallet), true);
        
        vm.stopPrank();
    }
    
    function testRewardsOnlyOncePer() public {
        // First verification
        vm.startPrank(userWallet);
        
        // Request puzzles
        uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        humanVerifier.requestPuzzles(signature);
        
        // Set mock verifier to return true
        vm.stopPrank();
        vm.prank(admin);
        mockVerifier.setReturnValue(true);
        vm.startPrank(userWallet);
        
        // Prepare verification data
        bytes memory proof = abi.encodePacked("MOCK_PROOF");
        uint256[] memory publicInputs = new uint256[](totalPuzzles);
        for (uint256 i = 0; i < totalPuzzles; i++) {
            publicInputs[i] = 1;
        }
        
        uint256[3][] memory solutions = new uint256[3][](newPuzzlesRequired);
        for (uint256 i = 0; i < newPuzzlesRequired; i++) {
            solutions[i][0] = 10;
            solutions[i][1] = 10;
            solutions[i][2] = uint256(keccak256(abi.encodePacked("SALT", i)));
        }
        
        // First verification - should get rewards
        humanVerifier.submitVerification(proof, publicInputs, solutions);
        
        uint256 initialNFTBalance = nft.balanceOf(userWallet);
        uint256 initialTokenBalance = token.balanceOf(userWallet);
        
        // Request puzzles again
        humanVerifier.resetUserAttempts(userWallet); // Admin only, so stop/start prank
        vm.stopPrank();
        vm.prank(admin);
        humanVerifier.resetUserAttempts(userWallet);
        vm.startPrank(userWallet);
        
        attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (v, r, s) = vm.sign(userPrivateKey, message);
        signature = abi.encodePacked(r, s, v);
        humanVerifier.requestPuzzles(signature);
        
        // Submit verification again
        humanVerifier.submitVerification(proof, publicInputs, solutions);
        
        // Check that balances didn't change (no additional rewards)
        assertEq(nft.balanceOf(userWallet), initialNFTBalance);
        assertEq(token.balanceOf(userWallet), initialTokenBalance);
        
        vm.stopPrank();
    }
    
    function testVerificationFailure() public {
        vm.startPrank(userWallet);
        
        // First request puzzles
        uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        humanVerifier.requestPuzzles(signature);
        
        // Set mock verifier to return false
        vm.stopPrank();
        vm.prank(admin);
        mockVerifier.setReturnValue(false);
        vm.startPrank(userWallet);
        
        // Prepare verification inputs
        bytes memory proof = abi.encodePacked("MOCK_PROOF");
        uint256[] memory publicInputs = new uint256[](totalPuzzles);
        
        // Fill with values to simulate all puzzles correct (but verifier will return false)
        for (uint256 i = 0; i < totalPuzzles; i++) {
            publicInputs[i] = 1;
        }
        
        // Prepare new puzzles
        uint256[3][] memory solutions = new uint256[3][](newPuzzlesRequired);
        for (uint256 i = 0; i < newPuzzlesRequired; i++) {
            solutions[i][0] = 10;
            solutions[i][1] = 10;
            solutions[i][2] = uint256(keccak256(abi.encodePacked("SALT", i)));
        }
        
        // Check initial attempts
        uint256 initialAttempts = humanVerifier.remainingAttempts(userWallet);
        
        // Submit verification
        humanVerifier.submitVerification(proof, publicInputs, solutions);
        
        // Check verification status (should remain false)
        assertEq(humanVerifier.isVerifiedHuman(userWallet), false);
        
        // Check attempts decremented
        assertEq(humanVerifier.remainingAttempts(userWallet), initialAttempts - 1);
        
        vm.stopPrank();
    }
    
    function testMultipleAttempts() public {
        vm.startPrank(userWallet);
        
        // Test multiple attempts with different signatures
        for (uint256 i = 0; i < maxAttempts; i++) {
            // Request puzzles with valid signature
            uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
            bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            humanVerifier.requestPuzzles(signature);
            
            // Prepare verification inputs (that will fail)
            bytes memory proof = abi.encodePacked("MOCK_PROOF");
            uint256[] memory publicInputs = new uint256[](totalPuzzles);
            
            // Prepare new puzzles
            uint256[3][] memory solutions = new uint256[3][](newPuzzlesRequired);
            for (uint256 j = 0; j < newPuzzlesRequired; j++) {
                solutions[j][0] = 10;
                solutions[j][1] = 10;
                solutions[j][2] = uint256(keccak256(abi.encodePacked("SALT", i, j)));
            }
            
            // Set mock verifier to return false
            vm.stopPrank();
            vm.prank(admin);
            mockVerifier.setReturnValue(false);
            vm.startPrank(userWallet);
            
            // Submit verification (will fail)
            humanVerifier.submitVerification(proof, publicInputs, solutions);
        }
        
        // After maxAttempts, should have no attempts left
        assertEq(humanVerifier.remainingAttempts(userWallet), 0);
        
        // Try to request puzzles again, should revert
        uint256 attemptNumber = humanVerifier.userAttemptNumber(userWallet);
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.expectRevert("No attempts remaining");
        humanVerifier.requestPuzzles(signature);
        
        vm.stopPrank();
    }
    
    function loadInitialPuzzles(uint256 count) internal {
        // Create dummy puzzles
        for (uint256 i = 0; i < count; i++) {
            uint256 x = 10;
            uint256 y = 10;
            uint256 salt = uint256(keccak256(abi.encodePacked("INIT_SALT", i)));
            
            puzzleManager.addPuzzle(x, y, salt, admin);
        }
    }
}