# Simple Payment Distributor Smart Contract Deployment Script

param (
    [string]$Network = "devnet",
    [string]$ProgramKeypairPath = "keypairs/program-keypair.json",
    [string]$FeePayerPath = "keypairs/fee-payer.json",
    [string]$ProgramBinaryPath = "target/deploy/payment_distributor.so",
    [switch]$Airdrop,
    [double]$AirdropAmount = 2.0,
    [switch]$ReuseKeypair
)

Write-Host "Deploying to $Network"

# Set the Solana network
Write-Host "Step 1: Configuring Solana CLI for $Network"
$endpoint = switch ($Network) {
    "devnet" { "https://api.devnet.solana.com" }
    "testnet" { "https://api.testnet.solana.com" }
    "mainnet" { "https://api.mainnet-beta.solana.com" }
    "localhost" { "http://localhost:8899" }
}
solana config set --url $endpoint
Write-Host "Solana CLI configured for $Network"

# Check if program keypair exists (should have been generated during build)
Write-Host "Step 2: Checking program keypair"
if (-not (Test-Path $ProgramKeypairPath)) {
    Write-Host "ERROR: Program keypair not found at $ProgramKeypairPath" -ForegroundColor Red
    Write-Host "Please run the build script first to generate the keypair and build the contract." -ForegroundColor Red
    exit 1
}

# Get the program ID
$programId = solana address -k $ProgramKeypairPath
Write-Host "Program ID: $programId"

# Check if fee payer keypair exists
Write-Host "Step 3: Checking fee payer keypair"
if (-not (Test-Path $FeePayerPath)) {
    Write-Host "Fee payer keypair not found, generating new keypair at $FeePayerPath"
    solana-keygen new --no-passphrase -o $FeePayerPath
    Write-Host "Generated new fee payer keypair"
} else {
    Write-Host "Using existing fee payer keypair at $FeePayerPath"
}

# Get the fee payer address
$feePayerAddress = solana address -k $FeePayerPath
Write-Host "Fee payer address: $feePayerAddress"

# Check fee payer balance
Write-Host "Step 4: Checking fee payer balance"
$balance = solana balance $feePayerAddress
Write-Host "Fee payer balance: $balance"

# Request airdrop if needed and not on mainnet
if ($Airdrop -and $Network -ne "mainnet") {
    Write-Host "Requesting airdrop of $AirdropAmount SOL for fee payer"
    try {
        solana airdrop $AirdropAmount $feePayerAddress
        $newBalance = solana balance $feePayerAddress
        Write-Host "New fee payer balance: $newBalance"
        
        $balanceValue = [decimal]($newBalance -replace '[^0-9.]', '')
        if ($balanceValue -lt 0.5) {
            Write-Host "WARNING: Fee payer balance is low ($balanceValue SOL). Deployment may fail." -ForegroundColor Yellow
            Write-Host "Consider funding the fee payer account manually or trying the airdrop again." -ForegroundColor Yellow
            $proceed = Read-Host "Do you want to proceed with deployment anyway? (y/n)"
            if ($proceed -ne "y") {
                Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
    } catch {
        Write-Host "WARNING: Airdrop failed. This is common on busy networks." -ForegroundColor Yellow
        Write-Host "Error details: $_" -ForegroundColor Yellow
        Write-Host "Current fee payer balance: $(solana balance $feePayerAddress)" -ForegroundColor Yellow
        $proceed = Read-Host "Do you want to proceed with deployment anyway? (y/n)"
        if ($proceed -ne "y") {
            Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
}

# Verify program ID in contract matches keypair
Write-Host "Step 5: Verifying program ID in contract"
$contractRsPath = "contract/contract.rs"
if (Test-Path $contractRsPath) {
    $contractRsContent = Get-Content $contractRsPath -Raw
    $programIdStart = 'declare_id!("'
    $programIdEnd = '")'
    $startPos = $contractRsContent.IndexOf($programIdStart)
    if ($startPos -ge 0) {
        $startPos += $programIdStart.Length
        $endPos = $contractRsContent.IndexOf($programIdEnd, $startPos)
        if ($endPos -ge 0) {
            $contractProgramId = $contractRsContent.Substring($startPos, $endPos - $startPos)
            Write-Host "Program ID in contract.rs: $contractProgramId"
            if ($contractProgramId -ne $programId) {
                Write-Host "ERROR: Program ID in contract ($contractProgramId) does not match keypair ($programId)" -ForegroundColor Red
                Write-Host "Please rebuild the contract with the correct program ID." -ForegroundColor Red
                exit 1
            } else {
                Write-Host "Program ID in contract matches keypair." -ForegroundColor Green
            }
        } else {
            Write-Host "Could not find end of program ID in $contractRsPath" -ForegroundColor Red
        }
    } else {
        Write-Host "Could not find program ID declaration in $contractRsPath" -ForegroundColor Red
    }
} else {
    Write-Host "Contract file not found at $contractRsPath" -ForegroundColor Red
    exit 1
}

# Deploy the program
Write-Host "Step 6: Deploying the smart contract"
$deployCommand = "solana program deploy --program-id $ProgramKeypairPath --keypair $FeePayerPath $ProgramBinaryPath"
Write-Host "Executing: $deployCommand"
Invoke-Expression $deployCommand
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "Smart contract deployed successfully to $programId" -ForegroundColor Green

# Note: Finalization is now handled by a separate script
Write-Host "Note: To finalize the program and make it non-upgradeable, run the finalize-program.ps1 script." -ForegroundColor Yellow

# Verify deployment
Write-Host "Step 7: Verifying deployment"
solana program show $programId
Write-Host "Check Solana Explorer at: https://explorer.solana.com/address/$programId?cluster=$Network"

# Deployment summary
Write-Host "Deployment Summary:"
Write-Host "Network: $Network"
Write-Host "Program ID: $programId"
Write-Host "Fee Payer: $feePayerAddress"

Write-Host "Next Steps:"
Write-Host "1. Verify deployment details with: solana program show $programId"
Write-Host "2. Finalize the program with: ./finalize-program.ps1"
Write-Host "3. Test the smart contract with: node scripts/manual-test.js"
Write-Host "4. Verify on Solana Explorer"
Write-Host "5. Update client configurations with Program ID: $programId"