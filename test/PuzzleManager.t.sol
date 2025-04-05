// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PuzzleManager.sol";

contract PuzzleManagerTest is Test {
    PuzzleManager public puzzleManager;
    
    address public admin = address(1);
    address public authorized = address(2);
    address public unauthorized = address(3);
    
    function setUp() public {
        vm.startPrank(admin);
        puzzleManager = new PuzzleManager();
        puzzleManager.setAuthorization(authorized, true);
        vm.stopPrank();
    }
    
    function testAddPuzzle() public {
        vm.startPrank(authorized);
        
        uint256 x = 10;
        uint256 y = 15;
        uint256 salt = 12345;
        
        uint256 puzzleId = puzzleManager.addPuzzle(x, y, salt, authorized);
        
        (uint256 retX, uint256 retY, uint256 retSalt, address retCreator, bool retActive) = puzzleManager.getPuzzle(puzzleId);
        
        assertEq(retX, x);
        assertEq(retY, y);
        assertEq(retSalt, salt);
        assertEq(retCreator, authorized);
        assertEq(retActive, true);
        
        vm.stopPrank();
    }
    
    function testAddPuzzleUnauthorized() public {
        vm.startPrank(unauthorized);
        
        uint256 x = 10;
        uint256 y = 15;
        uint256 salt = 12345;
        
        vm.expectRevert("Not authorized");
        puzzleManager.addPuzzle(x, y, salt, unauthorized);
        
        vm.stopPrank();
    }
    
    function testAddPuzzleInvalidCoordinates() public {
        vm.startPrank(authorized);
        
        // Test X out of range (too low)
        vm.expectRevert("X coordinate out of range");
        puzzleManager.addPuzzle(0, 10, 12345, authorized);
        
        // Test X out of range (too high)
        vm.expectRevert("X coordinate out of range");
        puzzleManager.addPuzzle(21, 10, 12345, authorized);
        
        // Test Y out of range (too low)
        vm.expectRevert("Y coordinate out of range");
        puzzleManager.addPuzzle(10, 0, 12345, authorized);
        
        // Test Y out of range (too high)
        vm.expectRevert("Y coordinate out of range");
        puzzleManager.addPuzzle(10, 21, 12345, authorized);
        
        vm.stopPrank();
    }
    
    function testAddDuplicatePuzzle() public {
        vm.startPrank(authorized);
        
        uint256 x = 10;
        uint256 y = 15;
        uint256 salt = 12345;
        
        // Add the first puzzle
        puzzleManager.addPuzzle(x, y, salt, authorized);
        
        // Try to add the same puzzle again
        vm.expectRevert("Puzzle already exists");
        puzzleManager.addPuzzle(x, y, salt, authorized);
        
        vm.stopPrank();
    }
    
    function testBatchAddPuzzles() public {
        vm.startPrank(authorized);
        
        uint256[3][] memory puzzles = new uint256[3][](3);
        
        // Define puzzles
        puzzles[0][0] = 5;
        puzzles[0][1] = 5;
        puzzles[0][2] = 100;
        
        puzzles[1][0] = 10;
        puzzles[1][1] = 10;
        puzzles[1][2] = 200;
        
        puzzles[2][0] = 15;
        puzzles[2][1] = 15;
        puzzles[2][2] = 300;
        
        // Initial count should be 0
        assertEq(puzzleManager.getPuzzleCount(), 0);
        
        // Add puzzles in batch
        puzzleManager.batchAddPuzzles(puzzles);
        
        // Should have 3 puzzles now
        assertEq(puzzleManager.getPuzzleCount(), 3);
        
        // Verify puzzles were added correctly
        (uint256 x0, uint256 y0, uint256 salt0, address creator0, bool active0) = puzzleManager.getPuzzle(0);
        assertEq(x0, 5);
        assertEq(y0, 5);
        assertEq(salt0, 100);
        assertEq(creator0, authorized);
        assertEq(active0, true);
        
        (uint256 x1, uint256 y1, uint256 salt1, address creator1, bool active1) = puzzleManager.getPuzzle(1);
        assertEq(x1, 10);
        assertEq(y1, 10);
        assertEq(salt1, 200);
        assertEq(creator1, authorized);
        assertEq(active1, true);
        
        vm.stopPrank();
    }
    
    function testBatchAddDuplicatePuzzles() public {
        vm.startPrank(authorized);
        
        uint256[3][] memory puzzles = new uint256[3][](3);
        
        // Define puzzles with one duplicate
        puzzles[0][0] = 5;
        puzzles[0][1] = 5;
        puzzles[0][2] = 100;
        
        puzzles[1][0] = 10;
        puzzles[1][1] = 10;
        puzzles[1][2] = 200;
        
        // Duplicate of first puzzle
        puzzles[2][0] = 5;
        puzzles[2][1] = 5;
        puzzles[2][2] = 100;
        
        // Add puzzles in batch (should not revert, just skip duplicates)
        puzzleManager.batchAddPuzzles(puzzles);
        
        // Should have 2 puzzles (skipped the duplicate)
        assertEq(puzzleManager.getPuzzleCount(), 2);
        
        vm.stopPrank();
    }
    
    function testDeactivatePuzzle() public {
        vm.startPrank(authorized);
        
        // Add a puzzle
        uint256 puzzleId = puzzleManager.addPuzzle(10, 10, 12345, authorized);
        
        // Verify it's active
        assertEq(puzzleManager.isPuzzleActive(puzzleId), true);
        
        // Deactivate it
        puzzleManager.deactivatePuzzle(puzzleId);
        
        // Verify it's inactive
        assertEq(puzzleManager.isPuzzleActive(puzzleId), false);
        
        vm.stopPrank();
    }
    
    function testDeactivateNonexistentPuzzle() public {
        vm.startPrank(authorized);
        
        // Try to deactivate a nonexistent puzzle
        vm.expectRevert("Puzzle does not exist");
        puzzleManager.deactivatePuzzle(999);
        
        vm.stopPrank();
    }
    
    function testGetPuzzleCount() public {
        vm.startPrank(authorized);
        
        // Initial count should be 0
        assertEq(puzzleManager.getPuzzleCount(), 0);
        
        // Add some puzzles
        puzzleManager.addPuzzle(5, 5, 100, authorized);
        puzzleManager.addPuzzle(10, 10, 200, authorized);
        puzzleManager.addPuzzle(15, 15, 300, authorized);
        
        // Count should be 3
        assertEq(puzzleManager.getPuzzleCount(), 3);
        
        vm.stopPrank();
    }
    
    function testGetPuzzleIdByIndex() public {
        vm.startPrank(authorized);
        
        // Add some puzzles
        puzzleManager.addPuzzle(5, 5, 100, authorized);
        puzzleManager.addPuzzle(10, 10, 200, authorized);
        
        // Get puzzle by index
        assertEq(puzzleManager.getPuzzleIdByIndex(0), 0);
        assertEq(puzzleManager.getPuzzleIdByIndex(1), 1);
        
        // Try to get puzzle with invalid index
        vm.expectRevert("Index out of bounds");
        puzzleManager.getPuzzleIdByIndex(2);
        
        vm.stopPrank();
    }
    
    function testSetAuthorization() public {
        vm.startPrank(admin);
        
        // Set authorization for a new address
        address newAuth = address(4);
        puzzleManager.setAuthorization(newAuth, true);
        
        // Verify authorization
        assertEq(puzzleManager.authorizedAddresses(newAuth), true);
        
        // Remove authorization
        puzzleManager.setAuthorization(newAuth, false);
        
        // Verify authorization removed
        assertEq(puzzleManager.authorizedAddresses(newAuth), false);
        
        vm.stopPrank();
    }
    
    function testSetAuthorizationUnauthorized() public {
        vm.startPrank(unauthorized);
        
        // Try to set authorization (should revert)
        address newAuth = address(4);
        vm.expectRevert("Ownable: caller is not the owner");
        puzzleManager.setAuthorization(newAuth, true);
        
        vm.stopPrank();
    }
}