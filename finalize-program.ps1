# Finalize Solana Program Script
# Makes an already-deployed program non-upgradeable

param (
    [string]$Network = "devnet",
    [string]$ProgramKeypairPath = "keypairs/program-keypair.json",
    [string]$FeePayerPath = "keypairs/fee-payer.json",
    [switch]$Airdrop,
    [double]$AirdropAmount = 1.0
)

# Set the current directory to the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Finalizing program on $Network"

# Set the Solana network
$endpoint = switch ($Network) {
    "devnet" { "https://api.devnet.solana.com" }
    "testnet" { "https://api.testnet.solana.com" }
    "mainnet" { "https://api.mainnet-beta.solana.com" }
    "localhost" { "http://localhost:8899" }
}
solana config set --url $endpoint
Write-Host "Solana CLI configured for $Network"

# Check program keypair
if (-not (Test-Path $ProgramKeypairPath)) {
    Write-Host "ERROR: Program keypair not found at $ProgramKeypairPath" -ForegroundColor Red
    exit 1
}
$programId = solana address -k $ProgramKeypairPath
Write-Host "Program ID: $programId"

# Check fee payer keypair
if (-not (Test-Path $FeePayerPath)) {
    Write-Host "ERROR: Fee payer keypair not found at $FeePayerPath" -ForegroundColor Red
    exit 1
}
$feePayerAddress = solana address -k $FeePayerPath
Write-Host "Fee payer address: $feePayerAddress"

# Check fee payer balance
$balance = solana balance $feePayerAddress
Write-Host "Fee payer balance: $balance"
$balanceValue = [decimal]($balance -replace '[^0-9.]', '')
if ($balanceValue -lt 0.000007) {
    if ($Airdrop -and $Network -ne "mainnet") {
        Write-Host "Requesting airdrop of $AirdropAmount SOL for fee payer"
        try {
            solana airdrop $AirdropAmount $feePayerAddress
            $newBalance = solana balance $feePayerAddress
            Write-Host "New fee payer balance: $newBalance"
        } catch {
            Write-Host "WARNING: Airdrop failed: $_" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "ERROR: Fee payer balance too low ($balanceValue SOL). Use -Airdrop or fund manually." -ForegroundColor Red
        exit 1
    }
}

# Set fee payer globally
Write-Host "Configuring fee payer"
solana config set --keypair $FeePayerPath
Write-Host "Fee payer set to $feePayerAddress"

# Finalize the program
Write-Host "Finalizing program to remove upgrade authority"
$finalizeCommand = "solana program set-upgrade-authority $programId --keypair $FeePayerPath --final"
Write-Host "Executing: $finalizeCommand"
Invoke-Expression $finalizeCommand
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to finalize program" -ForegroundColor Red
    exit 1
}
Write-Host "Program finalized successfully. It is now non-upgradeable." -ForegroundColor Green

# Verify immutability
Write-Host "Verifying immutability"
solana program show $programId
Write-Host "Check Solana Explorer for 'Upgrade Authority: None' at: https://explorer.solana.com/address/$programId?cluster=$Network"