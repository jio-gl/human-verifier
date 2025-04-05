/**
 * Visual Puzzle Generator for HumanVerifier
 * 
 * This script generates simple placeholder puzzles for the HumanVerifier system.
 * Each puzzle is a 20x20 grid where the user needs to find specific coordinates.
 */

const crypto = require('crypto');
const { createCanvas } = require('canvas');

/**
 * Generates a placeholder visual puzzle
 * @param {string|number} salt - Salt for deterministic generation (not used in placeholder)
 * @returns {Object} Object with puzzle image, solution and metadata
 */
function generatePuzzle(salt) {
  // Create a fixed solution (placeholder implementation)
  const x = 10;
  const y = 10;
  
  // Create a 400x400 canvas (20x20 cells of 20px each)
  const canvas = createCanvas(400, 400);
  const ctx = canvas.getContext('2d');
  
  // White background
  ctx.fillStyle = 'white';
  ctx.fillRect(0, 0, 400, 400);
  
  // Draw grid
  ctx.strokeStyle = '#ddd';
  ctx.lineWidth = 1;
  
  // Horizontal lines
  for (let i = 0; i <= 20; i++) {
    ctx.beginPath();
    ctx.moveTo(0, i * 20);
    ctx.lineTo(400, i * 20);
    ctx.stroke();
  }
  
  // Vertical lines
  for (let i = 0; i <= 20; i++) {
    ctx.beginPath();
    ctx.moveTo(i * 20, 0);
    ctx.lineTo(i * 20, 400);
    ctx.stroke();
  }
  
  // Draw a simple placeholder element at (10, 10)
  ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
  ctx.beginPath();
  ctx.arc(x * 20 - 10, y * 20 - 10, 8, 0, Math.PI * 2);
  ctx.fill();
  
  // Get the resulting image
  const image = canvas.toDataURL('image/png');
  
  return {
    salt: salt.toString(),
    solution: { x, y },
    image,
    metadata: {
      width: 20,
      height: 20,
      cellSize: 20,
      timestamp: Date.now()
    }
  };
}

/**
 * Verifies if a solution (x, y) is correct for a puzzle
 * @param {string|number} salt - Puzzle salt (not used in placeholder)
 * @param {number} solutionX - Proposed X coordinate (1-20)
 * @param {number} solutionY - Proposed Y coordinate (1-20)
 * @returns {boolean} true if solution is correct, false otherwise
 */
function verifyPuzzleSolution(salt, solutionX, solutionY) {
  // Placeholder implementation - always expects (10, 10)
  return solutionX === 10 && solutionY === 10;
}

/**
 * Generates a JSON with initial puzzles for bootstrapping
 * @param {number} count - Number of puzzles to generate
 * @returns {string} JSON with the generated puzzles
 */
function generateInitialPuzzlesJSON(count) {
  const puzzles = [];
  
  for (let i = 0; i < count; i++) {
    // In placeholder implementation, all puzzles have solution (10, 10)
    // Only the salt changes to make them unique
    const salt = crypto.randomBytes(16).toString('hex');
    
    puzzles.push([
      10, // x
      10, // y
      salt // each puzzle gets a unique salt
    ]);
  }
  
  return JSON.stringify(puzzles, null, 2);
}

// Export functions for use in other modules
module.exports = {
  generatePuzzle,
  verifyPuzzleSolution,
  generateInitialPuzzlesJSON
};

// If executed directly, generate sample puzzles
if (require.main === module) {
  const count = process.argv[2] ? parseInt(process.argv[2]) : 10;
  console.log(`Generating ${count} initial puzzles...`);
  const json = generateInitialPuzzlesJSON(count);
  
  const fs = require('fs');
  fs.mkdirSync('./data', { recursive: true });
  fs.writeFileSync('./data/initial_puzzles.json', json);
  
  console.log(`Puzzles saved to ./data/initial_puzzles.json`);
}