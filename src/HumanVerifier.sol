// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IVerifier.sol";
import "./interfaces/IPuzzleManager.sol";
import "./VerifiedHumanNFT.sol";
import "./HumanToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title HumanVerifier
 * @dev System to verify if a user is human by solving visual puzzles
 */
contract HumanVerifier is Ownable {
    // Interfaces
    IVerifier public verifier;
    IPuzzleManager public puzzleManager;
    VerifiedHumanNFT public nft;
    HumanToken public token;

    // System configuration
    uint256 public totalPuzzles = 35;
    uint256 public newPuzzlesRequired = 5;
    uint256 public minCorrectPuzzles = 27;
    uint256 public maxAttempts = 3;
    uint256 public puzzleConsumptionThreshold = 8;
    
    // System genesis hash for randomness
    bytes32 public genesisHash;

    // Mapping for user -> remaining attempts
    mapping(address => uint256) public remainingAttempts;
    
    // Mapping for user -> assigned puzzles (index in array is puzzle ID)
    mapping(address => uint256[]) public assignedPuzzles;
    
    // Mapping to track consumed puzzles (puzzleId -> success counter)
    mapping(uint256 => uint256) public puzzleSuccessCounter;
    
    // Mapping for verified users
    mapping(address => bool) public isVerifiedHuman;
    
    // Mapping to track user attempt numbers
    mapping(address => uint256) public userAttemptNumber;
    
    // Events
    event PuzzlesRequested(address indexed user, bytes32 signedHash);
    event PuzzlesAssigned(address indexed user, uint256[] puzzleIds);
    event VerificationAttempted(address indexed user, bool success, uint256 correctPuzzles);
    event RewardsIssued(address indexed user, uint256 tokenId, uint256 tokenAmount);
    event PuzzleConsumed(uint256 indexed puzzleId);
    event NewPuzzleAdded(uint256 indexed puzzleId, address indexed contributor);
    
    /**
     * @dev Constructor
     * @param _genesisHash Initial hash seed for the system
     * @param _verifier Address of the ZKP verifier contract
     * @param _puzzleManager Address of the puzzle manager
     * @param _nft Address of the VerifiedHumanNFT contract
     * @param _token Address of the HumanToken contract
     */
    constructor(
        bytes32 _genesisHash,
        address _verifier,
        address _puzzleManager,
        address _nft,
        address _token
    ) Ownable(msg.sender) {
        genesisHash = _genesisHash;
        verifier = IVerifier(_verifier);
        puzzleManager = IPuzzleManager(_puzzleManager);
        nft = VerifiedHumanNFT(_nft);
        token = HumanToken(_token);
    }
    
    /**
     * @dev Requests puzzles for verification using a signature for randomness
     * @param signature User's signature of hash(genesisHash, attemptNumber)
     */
    function requestPuzzles(bytes memory signature) external {
        require(remainingAttempts[msg.sender] > 0, "No attempts remaining");
        require(assignedPuzzles[msg.sender].length == 0, "Already have active puzzles");
        
        // Get current attempt number
        uint256 attemptNumber = userAttemptNumber[msg.sender];
        
        // Create the message that was signed
        bytes32 message = keccak256(abi.encodePacked(genesisHash, attemptNumber));
        
        // Recover the signer from the signature
        address signer = recoverSigner(message, signature);
        require(signer == msg.sender, "Invalid signature");
        
        // Use the signature hash as a random seed
        bytes32 seed = keccak256(signature);
        
        // Increment user attempt number for next time
        userAttemptNumber[msg.sender]++;
        
        // Select puzzles using the signature hash as seed
        selectPuzzles(msg.sender, seed);
        
        emit PuzzlesRequested(msg.sender, message);
    }
    
    /**
     * @dev Selects puzzles for a user based on a random seed
     * @param user Address of the user
     * @param seed Random seed from signature
     */
    function selectPuzzles(address user, bytes32 seed) internal {
        uint256[] memory selectedPuzzles = new uint256[](totalPuzzles);
        
        // Select random existing puzzles
        uint256 totalAvailablePuzzles = puzzleManager.getPuzzleCount();
        require(totalAvailablePuzzles >= totalPuzzles, "Not enough puzzles available");
        
        // Algorithm to select puzzles without repetition
        uint256 selected = 0;
        uint256 nonce = 0;
        
        while (selected < totalPuzzles) {
            uint256 puzzleIndex = uint256(keccak256(abi.encode(seed, nonce))) % totalAvailablePuzzles;
            uint256 puzzleId = puzzleManager.getPuzzleIdByIndex(puzzleIndex);
            
            // Verify that the puzzle is not consumed and hasn't been selected before
            if (puzzleSuccessCounter[puzzleId] < puzzleConsumptionThreshold && !isAlreadySelected(selectedPuzzles, puzzleId, selected)) {
                selectedPuzzles[selected] = puzzleId;
                selected++;
            }
            
            nonce++;
        }
        
        // Assign puzzles to the user
        assignedPuzzles[user] = selectedPuzzles;
        emit PuzzlesAssigned(user, selectedPuzzles);
    }
    
    /**
     * @dev Checks if a puzzle is already selected
     */
    function isAlreadySelected(uint256[] memory selectedPuzzles, uint256 puzzleId, uint256 count) private pure returns (bool) {
        for (uint256 i = 0; i < count; i++) {
            if (selectedPuzzles[i] == puzzleId) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Verifies the puzzle solutions submitted by the user
     * @param proof ZKP proof
     * @param publicInputs Public inputs for verification
     * @param solutions Solutions for adding new puzzles
     */
    function submitVerification(
        bytes memory proof,
        uint256[] memory publicInputs,
        uint256[3][] memory solutions
    ) external {
        require(assignedPuzzles[msg.sender].length == totalPuzzles, "No puzzles assigned");
        require(remainingAttempts[msg.sender] > 0, "No attempts remaining");
        require(solutions.length == newPuzzlesRequired, "Invalid number of new puzzles");
        
        // Verify the ZKP proof
        bool isValid = verifier.verifyProof(proof, publicInputs);
        
        // Count correct solutions according to the proof
        uint256 correctPuzzles = countCorrectPuzzles(publicInputs);
        
        if (isValid && correctPuzzles >= minCorrectPuzzles) {
            // Successful verification
            isVerifiedHuman[msg.sender] = true;
            
            // Update solved puzzle counters
            for (uint256 i = 0; i < totalPuzzles; i++) {
                uint256 puzzleId = assignedPuzzles[msg.sender][i];
                if (isPuzzleSolved(publicInputs, i)) {
                    puzzleSuccessCounter[puzzleId]++;
                    
                    // Mark puzzle as consumed if it reaches the threshold
                    if (puzzleSuccessCounter[puzzleId] == puzzleConsumptionThreshold) {
                        emit PuzzleConsumed(puzzleId);
                    }
                }
            }
            
            // Add new puzzles
            for (uint256 i = 0; i < newPuzzlesRequired; i++) {
                uint256 x = solutions[i][0];
                uint256 y = solutions[i][1];
                uint256 salt = solutions[i][2];
                
                require(x > 0 && x <= 20, "X coordinate out of range");
                require(y > 0 && y <= 20, "Y coordinate out of range");
                
                uint256 newPuzzleId = puzzleManager.addPuzzle(x, y, salt, msg.sender);
                emit NewPuzzleAdded(newPuzzleId, msg.sender);
            }
            
            // Issue rewards: mint NFT and transfer tokens
            issueRewards(msg.sender);
        } else {
            // Failed verification
            remainingAttempts[msg.sender]--;
        }
        
        // Clear assigned puzzles
        delete assignedPuzzles[msg.sender];
        
        emit VerificationAttempted(msg.sender, isValid && correctPuzzles >= minCorrectPuzzles, correctPuzzles);
    }
    
    /**
     * @dev Counts the number of correctly solved puzzles
     */
    function countCorrectPuzzles(uint256[] memory publicInputs) private pure returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < publicInputs.length; i++) {
            if (isPuzzleSolved(publicInputs, i)) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Determines if a puzzle was correctly solved based on public inputs
     */
    function isPuzzleSolved(uint256[] memory publicInputs, uint256 index) private pure returns (bool) {
        // Logic depends on how public inputs are structured
        // For simplicity, we assume a non-zero value means solved
        return publicInputs[index] > 0;
    }
    
    /**
     * @dev Recovers the signer address from a signature
     * @param message Message that was signed
     * @param signature The signature bytes
     * @return Address of the signer
     */
    function recoverSigner(bytes32 message, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        // Extract r, s, v from the signature
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // Version of signature should be 27 or 28, but some wallets use 0 or 1
        if (v < 27) {
            v += 27;
        }
        
        // Verify signature is valid for Ethereum signed messages
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
    
    // Administrative functions
    
    /**
     * @dev Reloads attempts for a user
     */
    function resetUserAttempts(address user) external onlyOwner {
        remainingAttempts[user] = maxAttempts;
    }
    
    /**
     * @dev Configures system parameters
     */
    function configure(
        uint256 _totalPuzzles,
        uint256 _newPuzzlesRequired,
        uint256 _minCorrectPuzzles,
        uint256 _maxAttempts,
        uint256 _puzzleConsumptionThreshold
    ) external onlyOwner {
        totalPuzzles = _totalPuzzles;
        newPuzzlesRequired = _newPuzzlesRequired;
        minCorrectPuzzles = _minCorrectPuzzles;
        maxAttempts = _maxAttempts;
        puzzleConsumptionThreshold = _puzzleConsumptionThreshold;
    }
    
    /**
     * @dev Updates the genesis hash
     */
    function updateGenesisHash(bytes32 _genesisHash) external onlyOwner {
        genesisHash = _genesisHash;
    }
    
    /**
     * @dev Issues rewards to a user for passing verification
     * @param user Address of the user to reward
     */
    function issueRewards(address user) internal {
        // Mint NFT if the user doesn't already have one
        if (!nft.hasToken(user)) {
            uint256 tokenId = nft.mint(user);
            
            // Reward HUMAN tokens
            token.rewardVerification(user);
            
            emit RewardsIssued(user, tokenId, token.VERIFICATION_REWARD());
        }
    }
}