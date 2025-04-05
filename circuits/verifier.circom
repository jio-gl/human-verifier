pragma circom 2.0.0;

include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/comparators.circom";

/**
 * @dev Component to verify a single puzzle
 * Verifies that the user knows the (x, y) coordinates that generate
 * the correct hash when combined with the salt.
 */
template VerifyPuzzle() {
    signal input x;         // X coordinate (private)
    signal input y;         // Y coordinate (private)
    signal input salt;      // Salt used to generate the puzzle (public)
    signal input hash;      // Hash stored in the smart contract (public)
    signal output isCorrect; // 1 if correct, 0 if not
    
    // Verify that x and y are in the range [1, 20]
    component rangeX = GreaterEqThan(5); // 2^5 = 32, enough for range [1, 20]
    rangeX.in[0] <== x;
    rangeX.in[1] <== 1;
    
    component rangeLessX = LessThan(5);
    rangeLessX.in[0] <== x;
    rangeLessX.in[1] <== 21; // x < 21
    
    component rangeY = GreaterEqThan(5);
    rangeY.in[0] <== y;
    rangeY.in[1] <== 1;
    
    component rangeLessY = LessThan(5);
    rangeLessY.in[0] <== y;
    rangeLessY.in[1] <== 21; // y < 21
    
    // Calculate the hash of (x, y, salt) using Poseidon
    component hasher = Poseidon(3);
    hasher.inputs[0] <== x;
    hasher.inputs[1] <== y;
    hasher.inputs[2] <== salt;
    
    // Verify that the calculated hash equals the stored one
    component isEqual = IsEqual();
    isEqual.in[0] <== hasher.out;
    isEqual.in[1] <== hash;
    
    // The result is correct only if the hash matches AND the coordinates are in range
    isCorrect <== isEqual.out * rangeX.out * rangeLessX.out * rangeY.out * rangeLessY.out;
}

/**
 * @dev Main component to verify multiple puzzles
 * Allows verification of 35 puzzles and determines if the threshold of 27 correct answers is met
 */
template VerifyMultiplePuzzles(numPuzzles) {
    signal input x[numPuzzles];         // X coordinates (private)
    signal input y[numPuzzles];         // Y coordinates (private)
    signal input salts[numPuzzles];     // Salts (public)
    signal input hashes[numPuzzles];    // Stored hashes (public)
    signal output result;               // 1 if threshold is met, 0 if not
    
    component verifiers[numPuzzles];
    signal correctCount;
    
    correctCount <== 0;
    
    // Verify each puzzle
    for (var i = 0; i < numPuzzles; i++) {
        verifiers[i] = VerifyPuzzle();
        verifiers[i].x <== x[i];
        verifiers[i].y <== y[i];
        verifiers[i].salt <== salts[i];
        verifiers[i].hash <== hashes[i];
        
        correctCount += verifiers[i].isCorrect;
    }
    
    // Threshold of correct answers to consider the proof valid (27 out of 35)
    component thresholdCheck = GreaterEqThan(6); // 2^6 = 64, enough for 35 puzzles
    thresholdCheck.in[0] <== correctCount;
    thresholdCheck.in[1] <== 27; // Minimum 27 correct puzzles
    
    // The result is 1 if the threshold is met, 0 if not
    result <== thresholdCheck.out;
}

// Instance of the main circuit with 35 puzzles
component main {public [salts, hashes]} = VerifyMultiplePuzzles(35);