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

1. **Docker**: Required for deterministic builds
2. **Rust and Cargo**: Required for building and installing the verification tools
3. **Solana CLI**: Required for interacting with the Solana network
4. **solana-verify CLI**: The primary tool for verification (our script will help install this)
5. **A public GitHub repository**: Your code must be in a public repository for verification

## Verification Process

Our project includes a verification script (`verify-contract.ps1`) that automates the verification process. Here's how it works:

### 1. Build the Contract

First, build your contract using our verifiable build script:

```powershell
./docker-build-verifiable.ps1 build
```

This creates a deterministic build of your smart contract.

### 2. Deploy the Contract

Deploy your contract to the Solana network:

```powershell
./deploy.ps1 -Network devnet
```

### 3. Verify the Contract

Run the verification script:

```powershell
./verify-contract.ps1 -Network devnet -RepoUrl https://github.com/yourusername/SimoDistribution
```

The script will:
- Check if the `solana-verify` CLI is installed
- Verify the on-chain program hash matches your local build
- Verify your program against your GitHub repository

### 4. Remote Verification (Optional)

For official verification that appears in Solana Explorer and other tools, use the remote verification option:

```powershell
./verify-contract.ps1 -Remote
```

This submits a verification request to the OtterSec API, which triggers a remote build of your program and verifies it against the on-chain program.

## Verification Options

The verification script supports several options:

- `-Network`: Solana network to use (default: devnet)
- `-ProgramKeypairPath`: Path to program keypair (default: keypairs/program-keypair.json)
- `-ProgramBinaryPath`: Path to program binary (default: target/deploy/payment_distributor.so)
- `-RepoUrl`: URL of the GitHub repository
- `-CommitHash`: Specific commit hash to verify against (optional)
- `-LibraryName`: Library name in Cargo.toml (default: payment_distributor)
- `-Remote`: Use remote verification via OtterSec API

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

## Resources

- [Official Solana Verification Documentation](https://docs.solana.com/developing/deployed-programs/deploying#verifiable-builds)
- [Solana Verify CLI Repository](https://github.com/Ellipsis-Labs/solana-verifiable-build)
- [OtterSec Verification API](https://verify.osec.io)