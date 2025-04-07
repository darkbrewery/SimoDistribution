# Keypair Management

This directory is for storing Solana keypairs used for smart contract deployment.

## CRITICAL: Program ID and Keypair Matching

**IMPORTANT**: The program ID hardcoded in the contract MUST match the public key of the keypair used for deployment. This is a common source of deployment failures.

Our build and deploy scripts automate this process:

1. **Automated Approach (Recommended)**:
   - The `docker-build-verifiable.ps1` script:
     - Generates a new program keypair (or reuses an existing one with `-ReuseKeypair`)
     - Updates the program ID in the contract automatically
     - Builds the contract with the correct program ID
   - The `deploy.ps1` script:
     - Verifies the program ID in the contract matches the keypair
     - Deploys the contract using the same keypair

2. **Manual Approach (Advanced)**:
   - Generate the keypair manually
   - Extract its public key (program ID)
   - Update the contract code with this program ID
   - Build and deploy using the same keypair

## Generating Keypairs

### Program Keypair

To generate a new program keypair:

```bash
solana-keygen new --no-passphrase -o program-keypair.json
```

After generating, get the program ID (public key):

```bash
solana address -k program-keypair.json
```

Update the program ID in the contract source code (`contract/contract.rs`):

```rust
solana_program::declare_id!("YOUR_PROGRAM_ID_HERE");
```

### Fee Payer Keypair

To generate a fee payer keypair (for paying deployment costs):

```bash
solana-keygen new --no-passphrase -o fee-payer.json
```

For devnet testing, you can request an airdrop:

```bash
solana airdrop 2 $(solana address -k fee-payer.json) --url https://api.devnet.solana.com
```

## Deployment Verification

After deployment, verify that the on-chain program ID matches what's in your contract:

```bash
solana program show $(solana address -k program-keypair.json)
```

## Security Notes

- Keep your keypairs secure and never commit them to version control
- Consider using environment variables or a secure vault for production keypairs
- Always have backups of your keypairs stored securely