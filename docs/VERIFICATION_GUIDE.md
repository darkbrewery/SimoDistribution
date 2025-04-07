# Solana Smart Contract Verification Guide

This guide provides detailed information about verifying your Solana smart contract using the official Solana verification process.

## What is Verification?

Verification ensures that the executable program deployed to Solana's network matches the source code in your repository. This provides transparency and security by allowing developers and users to confirm that the program running on-chain corresponds exactly to the public codebase.

The verification process involves comparing the hash of the on-chain program with the hash of the locally built program from the source code, ensuring no discrepancies between the two versions.

## Benefits of Verification

- **Security**: Guarantee that the program running on-chain matches the source code, preventing malicious alterations.
- **Transparency**: Allows other users and developers to validate that the on-chain program is trustworthy.
- **Trust**: Increases user confidence, as verified builds demonstrate that your program's on-chain behavior is aligned with your public code.
- **Discoverability**: Makes it easier for others to find your source code, documentation, and contact information.

## Prerequisites

Before verifying your smart contract, ensure you have:

1. **Docker**: Required for deterministic builds and verification (on Windows)
2. **Solana CLI**: Required for interacting with the Solana network
3. **A public GitHub repository**: Your code must be in a public repository for verification

> **Note for Windows Users**: The `solana-verify` CLI tool has compatibility issues on Windows. Our verification script uses Docker to run the verification process in a Linux container, which avoids these issues.

## Verification Process

Our project includes a verification script (`verify-contract.ps1`) that automates the verification process using Docker. Here's how it works:

### 1. Build the Contract

First, build your contract using our verifiable build script:

```powershell
./docker-build-verifiable.ps1 build
```

This creates a deterministic build of your smart contract and generates the necessary keypairs.

### 2. Deploy the Contract

Deploy your contract to the Solana network:

```powershell
./deploy.ps1 -Network devnet
```

### 3. Verify the Contract

Run the verification script:

```powershell
./verify-contract.ps1 -Network devnet -RepoUrl https://github.com/darkbrewery/SimoDistribution
```

The script will:
- Create a Docker container with the Solana toolchain and solana-verify CLI
- Verify the on-chain program hash matches your local build
- Verify your program against your GitHub repository

The verification process runs inside a Docker container, which ensures compatibility across different operating systems, especially Windows.

### 4. Remote Verification (Optional)

For official verification that appears in Solana Explorer and other tools, use the remote verification option:

```powershell
./verify-contract.ps1 -Network devnet -RepoUrl https://github.com/darkbrewery/SimoDistribution -Remote -Airdrop
```

The `-Airdrop` flag ensures your fee payer account has enough SOL to pay for the verification transaction. This is important because remote verification requires submitting a transaction to the Solana blockchain, which incurs a small fee.

This submits a verification request to the OtterSec API, which triggers a remote build of your program and verifies it against the on-chain program. The remote verification will make your program appear as verified in Solana Explorer, SolanaFM, and other tools.

## Verification Options

The verification script supports several options:

- `-Network`: Solana network to use (default: devnet)
- `-ProgramKeypairPath`: Path to program keypair (default: keypairs/program-keypair.json)
- `-FeePayerKeypairPath`: Path to fee payer keypair (default: keypairs/fee-payer.json)
- `-ProgramBinaryPath`: Path to program binary (default: target/deploy/payment_distributor.so)
- `-RepoUrl`: URL of the GitHub repository
- `-CommitHash`: Specific commit hash to verify against (optional)
- `-LibraryName`: Library name in Cargo.toml (default: payment_distributor)
- `-Remote`: Use remote verification via OtterSec API
- `-Airdrop`: Request an airdrop of SOL for the fee payer (useful for devnet/testnet)
- `-AirdropAmount`: Amount of SOL to airdrop (default: 1.0)

## Troubleshooting

### Hash Mismatch

If the on-chain hash doesn't match your local build, it could be due to:

1. **Non-deterministic build**: Ensure you're using our Docker-based build script
2. **Wrong program ID**: Verify you're using the correct program ID
3. **Code changes**: Ensure your repository contains the exact code used for deployment

### Remote Verification Failure

If remote verification fails:

1. **Repository access**: Ensure your repository is public
2. **Build issues**: Check if your code builds successfully in a clean environment
3. **Dependencies**: Ensure all dependencies are properly specified in Cargo.toml and Cargo.lock
4. **Fee payer balance**: Ensure your fee payer account has enough SOL (use the `-Airdrop` flag on devnet/testnet)
5. **Fee payer permissions**: Ensure your fee payer keypair is valid and has the necessary permissions

### Fee Payer Issues

For remote verification, you need a funded fee payer account:

1. **Create a fee payer**: If you don't have a fee payer keypair, create one with `solana-keygen new -o keypairs/fee-payer.json`
2. **Fund the account**: On mainnet, transfer SOL to the fee payer. On devnet/testnet, use the `-Airdrop` flag
3. **Check balance**: Verify the fee payer has enough SOL with `solana balance -k keypairs/fee-payer.json`

## Resources

- [Official Solana Verification Documentation](https://docs.solana.com/developing/deployed-programs/deploying#verifiable-builds)
- [Solana Verify CLI Repository](https://github.com/Ellipsis-Labs/solana-verifiable-build)
- [OtterSec Verification API](https://verify.osec.io)