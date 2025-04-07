# Solana Smart Contract Verification Script
# This script verifies a Solana smart contract using the official solana-verify CLI tool

param (
    [string]$Network = "devnet",
    [string]$ProgramKeypairPath = "keypairs/program-keypair.json",
    [string]$ProgramBinaryPath = "target/deploy/payment_distributor.so",
    [string]$RepoUrl = "https://github.com/yourusername/SimoDistribution",
    [string]$CommitHash = "",
    [string]$LibraryName = "payment_distributor",
    [switch]$Remote
)

# Set the current directory to the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Function to display help
function Show-Help {
    Write-Host "Solana Smart Contract Verification Script"
    Write-Host "Usage: .\verify-contract.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Network <network>            - Solana network to use (default: devnet)"
    Write-Host "  -ProgramKeypairPath <path>    - Path to program keypair (default: keypairs/program-keypair.json)"
    Write-Host "  -ProgramBinaryPath <path>     - Path to program binary (default: target/deploy/payment_distributor.so)"
    Write-Host "  -RepoUrl <url>                - URL of the GitHub repository (default: https://github.com/yourusername/SimoDistribution)"
    Write-Host "  -CommitHash <hash>            - Specific commit hash to verify against (optional)"
    Write-Host "  -LibraryName <name>           - Library name in Cargo.toml (default: payment_distributor)"
    Write-Host "  -Remote                       - Use remote verification via OtterSec API"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\verify-contract.ps1 -Network devnet"
    Write-Host "  .\verify-contract.ps1 -Network mainnet -RepoUrl https://github.com/yourusername/SimoDistribution -CommitHash abc123"
    Write-Host "  .\verify-contract.ps1 -Remote"
}

# Function to check if solana-verify is installed
function Check-SolanaVerify {
    try {
        $verifyVersion = Invoke-Expression "solana-verify --version"
        Write-Host "Found solana-verify: $verifyVersion"
        return $true
    }
    catch {
        Write-Host "solana-verify CLI not found" -ForegroundColor Yellow
        return $false
    }
}

# Function to install solana-verify
function Install-SolanaVerify {
    Write-Host "Installing solana-verify CLI..."
    try {
        Invoke-Expression "cargo install solana-verify"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error installing solana-verify" -ForegroundColor Red
            exit 1
        }
        Write-Host "solana-verify CLI installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error installing solana-verify: $_" -ForegroundColor Red
        Write-Host "Please make sure Rust and Cargo are installed and try again." -ForegroundColor Red
        exit 1
    }
}

# Function to verify the program
function Verify-Program {
    # Get the program ID
    $programId = solana address -k $ProgramKeypairPath
    Write-Host "Program ID: $programId"
    
    # Set the Solana network
    Write-Host "Configuring Solana CLI for $Network"
    $endpoint = switch ($Network) {
        "devnet" { "https://api.devnet.solana.com" }
        "testnet" { "https://api.testnet.solana.com" }
        "mainnet" { "https://api.mainnet-beta.solana.com" }
        "localhost" { "http://localhost:8899" }
    }
    solana config set --url $endpoint
    
    # Verify the program hash
    Write-Host "Verifying program hash..."
    $onChainHash = solana-verify get-program-hash -u $endpoint $programId
    $localHash = solana-verify get-executable-hash $ProgramBinaryPath
    
    Write-Host "On-chain hash: $onChainHash"
    Write-Host "Local hash: $localHash"
    
    if ($onChainHash -eq $localHash) {
        Write-Host "Program hash verification successful! ✅" -ForegroundColor Green
    } else {
        Write-Host "Program hash verification failed! ❌" -ForegroundColor Red
        Write-Host "The on-chain program does not match the local build." -ForegroundColor Red
        $proceed = Read-Host "Do you want to proceed with repository verification anyway? (y/n)"
        if ($proceed -ne "y") {
            exit 1
        }
    }
    
    # Verify against repository
    Write-Host "Verifying program against repository..."
    
    $verifyCommand = "solana-verify verify-from-repo -u $endpoint --program-id $programId $RepoUrl --library-name $LibraryName"
    
    if ($CommitHash) {
        $verifyCommand += " --commit-hash $CommitHash"
    }
    
    if ($Remote) {
        $verifyCommand += " --remote"
    }
    
    Write-Host "Executing: $verifyCommand"
    Invoke-Expression $verifyCommand
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Repository verification failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Repository verification completed" -ForegroundColor Green
}

# Main script logic
if ($args -contains "-help" -or $args -contains "--help" -or $args -contains "help") {
    Show-Help
    exit 0
}

# Check if solana-verify is installed
$solanaVerifyInstalled = Check-SolanaVerify
if (-not $solanaVerifyInstalled) {
    $installVerify = Read-Host "solana-verify CLI is not installed. Do you want to install it now? (y/n)"
    if ($installVerify -eq "y") {
        Install-SolanaVerify
    } else {
        Write-Host "solana-verify CLI is required for verification. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Verify the program
Verify-Program

Write-Host "Verification process completed!" -ForegroundColor Green