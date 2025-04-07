# Payment Distributor Smart Contract Deployment Guide

This guide explains how to deploy the Payment Distributor smart contract to the Solana blockchain with a specific program ID.

## Understanding Program IDs in Solana

In Solana, a program's address (Program ID) is determined by the keypair used to deploy it. When you hardcode a program ID in your contract:

```rust
solana_program::declare_id!("AuyVx5bYQvV9tL2S3xv4cEGos9t5tgHsDxtqjmgZzM8S");
```

You must deploy using the keypair that corresponds to this public key. Otherwise, the deployment will fail or create a mismatch between your code and the deployed program.

## Prerequisites

- Solana CLI tools installed
- Docker installed (for building the contract)
- PowerShell (for Windows)

## Deployment Process

Our deployment process follows these steps:

1. Generate a program keypair
2. Update the program ID in the contract source code to match the program keypair
3. Build the contract with the updated program ID
4. Deploy the contract using the program keypair

## Using the Deployment Script

We've created a PowerShell script (`deploy.ps1`) that automates this process:

```powershell
# Deploy to devnet with default options
.\deploy.ps1

# Deploy to devnet with airdrop for the fee payer
.\deploy.ps1 -Airdrop

# Deploy to mainnet with specific keypairs
.\deploy.ps1 -Network mainnet -ProgramKeypairPath path/to/program-keypair.json -FeePayerPath path/to/fee-payer.json
```

### Script Parameters

- `Network`: Network to deploy to (options: "mainnet", "testnet", "devnet", "localhost"; default: "devnet")
- `ProgramKeypairPath`: Path to the program keypair (default: "program-keypair.json")
- `FeePayerPath`: Path to the fee payer keypair (default: "fee-payer.json")
- `ProgramBinaryPath`: Path to the compiled program binary (default: "target/deploy/payment_distributor.so")
- `Airdrop`: Whether to request an airdrop for the fee payer (only works on devnet and localhost)
- `AirdropAmount`: Amount of SOL to request in the airdrop (default: 2.0)

## Manual Deployment Steps

If you prefer to deploy manually, follow these steps:

### 1. Generate Keypairs

```bash
# Generate program keypair
solana-keygen new --no-passphrase -o program-keypair.json

# Generate fee payer keypair (if you don't already have one)
solana-keygen new --no-passphrase -o fee-payer.json

# Get the program ID
solana address -k program-keypair.json
```

### 2. Update the Program ID in the Contract

Edit `src/lib.rs` and `contract.rs` to update the program ID:

```rust
// Replace with your program ID
solana_program::declare_id!("YOUR_PROGRAM_ID_HERE");
```

### 3. Build the Contract

```bash
.\docker-build.ps1 build
```

### 4. Deploy the Contract

```bash
solana program deploy --program-id program-keypair.json target/deploy/payment_distributor.so
```

### 5. Verify the Deployment

```bash
solana program show $(solana address -k program-keypair.json)
```

## Deployment Costs

Deploying a Solana program requires SOL to cover:

1. The rent-exempt reserve for the program account (proportional to the program size)
2. Transaction fees

For the Payment Distributor contract, you'll need approximately:
- 0.5-1.0 SOL for the program account (varies based on program size)
- 0.0001 SOL for transaction fees

Make sure your fee payer account has sufficient SOL before deploying.

## Troubleshooting

### "Account has insufficient funds" error

This means your fee payer account doesn't have enough SOL. You can:

1. Request an airdrop (on devnet):
   ```
   solana airdrop 2 YOUR_FEE_PAYER_ADDRESS --url https://api.devnet.solana.com
   ```

2. Use a different fee payer account that has funds:
   ```
   solana program deploy --program-id program-keypair.json --keypair FUNDED_KEYPAIR.json target/deploy/payment_distributor.so
   ```

### "Error: airdrop request failed" error

This usually means you've hit the rate limit for airdrops. Wait a few minutes and try again, or use a different fee payer account.

## Production Deployment Checklist

Before deploying to mainnet:

1. Thoroughly test the contract on devnet
2. Audit the contract code for security vulnerabilities
3. Ensure you have a secure backup of the program keypair
4. Have sufficient SOL in your fee payer account
5. Update the program ID in all relevant configuration files