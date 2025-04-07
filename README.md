# Simo Payment Distributor Smart Contract

This repository contains the Solana smart contract for the Simo Payment Distributor, which handles payment distribution according to the following rules:

- Treasury wallet always gets at least 50% of the total payment
- First referral gets 20% (max 0.2 SOL)
- Second tier referral (who referred the referrer) gets 5% (max 0.05 SOL)
- When there's no referral, 50% goes to treasury and 50% goes to team wallet
- If there's a first referral but no second referral, the second referral's portion goes to the team wallet

## Repository Structure

```
SimoDistribution/
├── contract/             # Smart contract source code
│   └── contract.rs       # Main contract implementation
├── config/               # Configuration files
│   └── Cargo.toml        # Rust dependencies
├── client/               # Client integration code
│   └── direct-web3-client.ts  # TypeScript client for contract interaction
├── keypairs/             # Directory for storing keypairs (gitignored)
│   ├── .gitignore        # Prevents keypairs from being committed
│   └── README.md         # Instructions for keypair management
├── docs/                 # Documentation
│   ├── README.md         # General documentation
│   └── DEPLOYMENT_GUIDE.md  # Detailed deployment instructions
├── docker-build-verifiable.ps1  # Script for building the contract
├── deploy.ps1            # Script for deploying the contract
├── Dockerfile            # Docker configuration for build environment
├── docker-compose.yml    # Docker Compose configuration
└── README.md             # This file
```

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/) (for Windows)

## Quick Start

### 1. Generate Keypairs

First, generate the necessary keypairs:

```bash
# Navigate to the keypairs directory
cd keypairs

# Generate program keypair
solana-keygen new --no-passphrase -o program-keypair.json

# Get the program ID
solana address -k program-keypair.json

# Generate fee payer keypair
solana-keygen new --no-passphrase -o fee-payer.json
```

### 2. Update Program ID

Update the program ID in the contract source code (`contract/contract.rs`):

```rust
solana_program::declare_id!("YOUR_PROGRAM_ID_HERE");
```

### 3. Build and Deploy Process

The build and deploy process has been separated to ensure proper program ID management:

#### Step 1: Build the Contract

The build process generates a new program keypair, updates the program ID in the contract, and builds the optimized smart contract:

> **Note on Verifiability**:
> While our `docker-build-verifiable.ps1` script provides a foundation for verifiability by using pinned dependencies and generating a SHA-256 hash, for complete verification that can be recognized by tools like Solana Explorer, you should use the official `solana-verify` CLI tool. See the [Official Solana Verification Documentation](https://docs.solana.com/developing/deployed-programs/deploying#verifiable-builds) for more information.

```powershell
# From the root directory, build with a new program keypair
./docker-build-verifiable.ps1 build

# Or to reuse an existing keypair (for upgrades or testing)
./docker-build-verifiable.ps1 build -ReuseKeypair
```

#### Step 2: Deploy the Contract

After building, deploy the contract to the Solana network:

```powershell
# Deploy to devnet with default options
./deploy.ps1

# Deploy to devnet with airdrop for the fee payer (adds SOL to pay for deployment)
./deploy.ps1 -Airdrop -AirdropAmount 2.0

# Deploy to mainnet with specific keypairs
./deploy.ps1 -Network mainnet -ProgramKeypairPath keypairs/program-keypair.json -FeePayerPath keypairs/fee-payer.json
```

> **IMPORTANT**:
> - Always build the contract before deploying. The build process generates the program keypair and updates the program ID in the contract.
> - The deploy process verifies that the program ID in the contract matches the keypair.
> - When using the `-Airdrop` flag, the script will attempt to airdrop SOL to the fee payer account. This only works on devnet and testnet, and may fail if the network is busy. If the airdrop fails or the balance is low, the script will ask if you want to proceed with deployment anyway.
> - After deployment, use the verification script to make your contract officially verifiable on Solana Explorer and other tools.

## Documentation

For more detailed information, please refer to:

- [General Documentation](docs/README.md)
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Keypair Management](keypairs/README.md)
- [Verification Guide](docs/VERIFICATION_GUIDE.md)

## Verifying Your Smart Contract

After deploying your smart contract, you can verify it using the official Solana verification process. This makes your contract verifiable on Solana Explorer, SolanaFM, and other tools.

### Using the Verification Script

We've provided a verification script that automates the process:

```powershell
# Basic verification on devnet
./verify-contract.ps1

# Verification with specific options
./verify-contract.ps1 -Network mainnet -RepoUrl https://github.com/yourusername/SimoDistribution -CommitHash abc123

# Remote verification via OtterSec API
./verify-contract.ps1 -Remote
```

### Verification Process

The verification script:

1. Checks if the `solana-verify` CLI tool is installed and offers to install it if not
2. Verifies that the on-chain program hash matches your local build
3. Verifies your program against your GitHub repository
4. Optionally submits the verification data to the OtterSec API for remote verification

For more details on the verification process, run:

```powershell
./verify-contract.ps1 -help
```

## Integration with Simo Project

After deploying the smart contract, update the `PAYMENT_DISTRIBUTOR_PROGRAM_ID` in the Simo project's `src/config/solana.config.ts` file with the deployed program ID.