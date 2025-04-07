# Payment Distributor Smart Contract

This is a Solana smart contract for distributing payments according to the following rules:

- Treasury wallet always gets at least 50% of the total payment
- First referral gets 20% (max 0.2 SOL)
- Second tier referral (who referred the referrer) gets 5% (max 0.05 SOL)
- When there's no referral, 50% goes to treasury and 50% goes to team wallet
- If there's a first referral but no second referral, the second referral's portion goes to the team wallet

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)
- [Node.js](https://nodejs.org/en/download/) (for testing)
- [Yarn](https://yarnpkg.com/getting-started/install) (for testing)

## Setup

1. Install dependencies:

```bash
yarn install
```

2. Generate a new program ID (if needed):

```bash
solana-keygen new -o target/deploy/payment_distributor-keypair.json
```

This creates a keypair file at `target/deploy/payment_distributor-keypair.json`. The program ID is derived from this keypair.

3. Update the program ID in the following files (if needed):
   - `programs/payment-distributor/src/lib.rs` (replace `declare_id!("PAYMENT_DISTRIBUTOR_PROGRAM_ID")`)
   - `Anchor.toml` (replace all occurrences of `PAYMENT_DISTRIBUTOR_PROGRAM_ID`)

## Build and Deploy

### Build Using Docker (Recommended)

Build the optimized smart contract using Docker (this approach avoids Rust version compatibility issues):

```powershell
# Windows (PowerShell)
.\docker-build.ps1 build
```

This will:
1. Build a Docker image with all necessary dependencies
2. Start a Docker container
3. Build the optimized smart contract using Solana BPF tools
4. Apply additional stripping to fix ELF errors
5. Output the compiled binary to `./payment_distributor.so` and `./target/deploy/payment_distributor.so`

Available docker-build.ps1 commands:
- `build` - Build the optimized smart contract
- `clean` - Clean build artifacts
- `shell` - Open a shell in the Docker container
- `help` - Show help information

### Deploy Using Solana CLI

After building, deploy the smart contract using the Solana CLI directly:

```bash
# 1. Configure Solana for the desired network
solana config set --url https://api.devnet.solana.com  # For devnet
# solana config set --url https://api.testnet.solana.com  # For testnet
# solana config set --url https://api.mainnet-beta.solana.com  # For mainnet

# 2. Deploy using the keypair file generated during setup
solana program deploy ./payment_distributor.so --keypair target/deploy/payment_distributor-keypair.json
```

The `--keypair` parameter specifies the path to your keypair file (not the program ID itself). This file contains the private key needed to deploy the program.

### Get the Program ID

After deployment, get the program ID:

```bash
solana address -k target/deploy/payment_distributor-keypair.json
```

This command outputs the program ID, which is derived from the public key in your keypair file.

### Update Your Application

Update the `PAYMENT_DISTRIBUTOR_PROGRAM_ID` in `src/config/solana.config.ts`:

```typescript
PAYMENT_DISTRIBUTOR_PROGRAM_ID: 'YOUR_PROGRAM_ID_HERE',
```

## Testing

Run the tests to verify the smart contract works correctly:

```bash
# Run tests using Anchor
anchor test --provider.cluster devnet  # For devnet
# anchor test --provider.cluster testnet  # For testnet
# anchor test --provider.cluster mainnet  # For mainnet
```

The tests verify different payment distribution scenarios:
- No referrals (50/50 split between treasury and team)
- First referral only (with max cap of 0.2 SOL)
- Both referrals (with max caps)
- Large payments (to test the caps)

## Troubleshooting

If you encounter any issues with the Docker build, try the following:

1. Rebuild the Docker image:
   ```bash
   docker-compose build --no-cache
   ```

2. Check the Docker logs:
   ```bash
   docker-compose logs
   ```

3. Ensure your Solana wallet is properly configured:
   ```bash
   solana config get
   ```

4. Verify the program ID matches in all configuration files:
   ```bash
   solana address -k target/deploy/payment_distributor-keypair.json
   ```

5. If you encounter Rust version compatibility issues when trying to use npm scripts for deployment (like `npm run deploy:devnet`), use the Docker-based build approach described in this document instead.

## Cost Analysis

### Deployment Cost Savings

The optimized contract provides significant cost savings:

| Version | Size | Deployment Cost (SOL) | Savings |
|---------|------|----------------------|---------|
| Original | 377KB | ~2.26 SOL | - |
| Optimized | 14KB | ~0.08 SOL | ~2.18 SOL (96%) |

*Note: Costs are approximate based on current Solana deployment fees of ~0.006 SOL per KB*

## Integration with Simo Project

After deploying the smart contract, update the `PAYMENT_DISTRIBUTOR_PROGRAM_ID` in the Simo project's `src/config/solana.config.ts` file with the deployed program ID. The Simo project will automatically use the smart contract for payment distribution.

## Note on Alternative Deployment Methods

The `deploy.js` script in the scripts directory was an alternative approach to deployment, but it may encounter Rust version compatibility issues. The Docker-based build approach described above is the recommended method as it provides a consistent build environment.
