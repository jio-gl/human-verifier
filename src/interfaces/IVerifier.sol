// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IVerifier
 * @dev Interface for the ZKP proof verifier
 */
interface IVerifier {
    /**
     * @dev Verifies a ZKP proof
     * @param proof ZKP proof
     * @param publicInputs Public inputs
     * @return If the proof is valid
     */
    function verifyProof(
        bytes memory proof,
        uint256[] memory publicInputs
    ) external view returns (bool);
}