# HumanVerifier

HumanVerifier is a blockchain-based system that verifies whether a user is human by solving visual puzzles, using Zero-Knowledge Proofs (ZKP) to ensure privacy and security.

## Description

The system presents users with visual puzzles where they need to identify specific (x,y) coordinates on a 20x20 grid. Using deterministic pseudo-randomness and ZKP, the system:

- Randomly selects 35 existing puzzles and asks the user to create 5 new ones (total: 40)
- Requires a minimum of 27 correct answers (77.1%) to be verified as human
- Allows up to 3 attempts to "warm up"
- Provides a 95% success rate for humans and only 0.15% for AIs

## Key Features

- **Optimized Security**: Ideal balance between human usability and AI resistance
- **Protection Against Brute Force**: Puzzles are "consumed" after 8 valid correct solutions
- **Zero-Knowledge Verification**: Uses ZKPs to verify solutions without exposing them
- **Flexible Administration**: Configurable parameters by the administrator
- **Rewards System**: Users get a "VerifiedHuman" NFT and 10 HUMAN tokens upon verification

## Technologies

- **Smart Contracts**: Solidity with Foundry
- **ZKP**: Circom circuits and zk-SNARKs
- **Randomness**: Uses ECRecover for deterministic puzzle selection
- **Puzzles**: Deterministic generation based on cryptographic seeds
- **Tokens**: ERC-721 NFT and ERC-20 reward tokens

## Installation

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Circom](https://docs.circom.io/getting-started/installation/)
- [Node.js](https://nodejs.org/) (v14+)
- [Yarn](https://yarnpkg.com/) (optional)

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/human-verifier.git
cd human-verifier

# Install dependencies
forge install
yarn install  # or npm install

# Compile contracts
forge build

# Compile Circom circuits
cd circuits
./compile.sh
```

## Usage

### Deployment

```bash
# Configure environment variables
cp .env.example .env
# Edit .env with your keys

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Administration

```bash
# Load initial puzzles
forge script script/LoadInitialPuzzles.s.sol --rpc-url $RPC_URL --private-key $ADMIN_KEY --broadcast

# Configure parameters
forge script script/Configure.s.sol --rpc-url $RPC_URL --private-key $ADMIN_KEY --broadcast
```

## How It Works

### Flow Diagram

1. **Puzzle Selection**: 
   - The system selects 35 existing puzzles using deterministic randomness
   - Puzzles are chosen only if they haven't been "consumed" (solved 8 times)

2. **Presentation to User**:
   - The frontend displays the puzzles, one by one
   - Each puzzle is a 20x20 grid deterministically generated from a salt

3. **Solution**:
   - The user identifies and provides (x,y) coordinates as solutions
   - They must also create 5 new puzzles by providing their coordinates

4. **Verification**:
   - The system uses ZKP to verify that the user knows at least 27 solutions
   - Verification is done without revealing the specific solutions

5. **Result**:
   - If the user passes verification, they are registered as human
   - Correctly solved puzzles approach their consumption threshold
   - New puzzles are added to the pool for future users

### Scalability and Security

- With the current parameters (35 puzzles, 27 correct answers), the system achieves:
  - 95% success rate for humans
  - Only 0.15% false positives for AIs
- The "consumption" mechanism prevents brute force attacks
- The requirement to create new puzzles ensures the pool always grows

## License

MIT