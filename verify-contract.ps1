# Solana Smart Contract Verification Script
# This script verifies a Solana smart contract using Docker (for Windows compatibility)
# Reuses the same Docker container from docker-build-verifiable.ps1

param (
    [string]$Network = "devnet",
    [string]$ProgramKeypairPath = "keypairs/program-keypair.json",
    [string]$ProgramBinaryPath = "target/deploy/payment_distributor.so",
    [string]$RepoUrl = "https://github.com/darkbrewery/SimoDistribution",
    [string]$CommitHash = "",
    [string]$LibraryName = "payment_distributor",
    [switch]$Remote
)

# Set the current directory to the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Function to display help
function Show-Help {
    Write-Host "Solana Smart Contract Verification Script (Using Docker)"
    Write-Host "Usage: .\verify-contract.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Network <network>            - Solana network to use (default: devnet)"
    Write-Host "  -ProgramKeypairPath <path>    - Path to program keypair (default: keypairs/program-keypair.json)"
    Write-Host "  -ProgramBinaryPath <path>     - Path to program binary (default: target/deploy/payment_distributor.so)"
    Write-Host "  -RepoUrl <url>                - URL of the GitHub repository (default: https://github.com/darkbrewery/SimoDistribution)"
    Write-Host "  -CommitHash <hash>            - Specific commit hash to verify against (optional)"
    Write-Host "  -LibraryName <name>           - Library name in Cargo.toml (default: payment_distributor)"
    Write-Host "  -Remote                       - Use remote verification via OtterSec API"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\verify-contract.ps1 -Network devnet"
    Write-Host "  .\verify-contract.ps1 -Network mainnet -RepoUrl https://github.com/darkbrewery/SimoDistribution -CommitHash abc123"
    Write-Host "  .\verify-contract.ps1 -Remote"
}

# Function to check if Docker is installed
function Check-Docker {
    try {
        $dockerVersion = docker --version
        Write-Host "Found Docker: $dockerVersion"
        return $true
    }
    catch {
        Write-Host "Docker not found" -ForegroundColor Red
        Write-Host "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
        exit 1
    }
}

# Function to build the Docker image (reusing code from docker-build-verifiable.ps1)
function Build-DockerImage {
    Write-Host "Building Docker image with Solana BPF toolchain and solana-verify..."
    
    # Create a temporary Dockerfile with pinned versions
    $tempDockerfile = [System.IO.Path]::GetTempFileName()
    
    @'
FROM ubuntu:24.04

WORKDIR /app

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y build-essential pkg-config libssl-dev libudev-dev git curl binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Rust with a specific version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Solana CLI and toolchain - pinned to version 1.18.26
RUN sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)" && \
    /root/.local/share/solana/install/active_release/bin/solana-install init 1.18.26
ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# Install solana-verify with --locked flag
RUN cargo install solana-verify --locked

# Keep container running
CMD ["tail", "-f", "/dev/null"]
'@ | Set-Content $tempDockerfile
    
    # Build the Docker image
    docker build -t payment-distributor-verifier -f $tempDockerfile .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error building Docker image" -ForegroundColor Red
        exit 1
    }
    
    Remove-Item $tempDockerfile
}

# Function to start the Docker container
function Start-DockerContainer {
    Write-Host "Starting Docker container..."
    docker run -d --name payment-distributor-verifier -v ${PWD}:/app payment-distributor-verifier
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error starting Docker container" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 2
}

# Function to verify the program using Docker
function Verify-Program {
    # Get the program ID
    $programId = solana address -k $ProgramKeypairPath
    Write-Host "Program ID: $programId"
    
    # Set the Solana network
    $endpoint = switch ($Network) {
        "devnet" { "https://api.devnet.solana.com" }
        "testnet" { "https://api.testnet.solana.com" }
        "mainnet" { "https://api.mainnet-beta.solana.com" }
        "localhost" { "http://localhost:8899" }
    }
    
    # Verify the program hash
    Write-Host "Verifying program hash..."
    $onChainHashCommand = "docker exec -t payment-distributor-verifier bash -c 'cd /app && solana-verify get-program-hash -u $endpoint $programId'"
    $localHashCommand = "docker exec -t payment-distributor-verifier bash -c 'cd /app && solana-verify get-executable-hash $ProgramBinaryPath'"
    
    $onChainHash = Invoke-Expression $onChainHashCommand
    $localHash = Invoke-Expression $localHashCommand
    
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
    
    $verifyCommand = "docker exec -t payment-distributor-verifier bash -c 'cd /app && solana-verify verify-from-repo -u $endpoint --program-id $programId $RepoUrl --library-name $LibraryName"
    
    if ($CommitHash) {
        $verifyCommand += " --commit-hash $CommitHash"
    }
    
    if ($Remote) {
        $verifyCommand += " --remote"
    }
    
    $verifyCommand += "'"
    
    Write-Host "Executing: $verifyCommand"
    Invoke-Expression $verifyCommand
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Repository verification failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Repository verification completed" -ForegroundColor Green
}

# Function to stop the Docker container
function Stop-DockerContainer {
    Write-Host "Stopping Docker container..."
    docker stop payment-distributor-verifier | Out-Null
    docker rm payment-distributor-verifier | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error stopping Docker container" -ForegroundColor Red
        exit 1
    }
}

# Main script logic
try {
    if ($args -contains "-help" -or $args -contains "--help" -or $args -contains "help") {
        Show-Help
        exit 0
    }

    # Check if Docker is installed
    Check-Docker
    
    # Build the Docker image
    Build-DockerImage
    
    # Start the Docker container
    Start-DockerContainer
    
    # Verify the program
    Verify-Program
    
    # Stop the Docker container
    Stop-DockerContainer
    
    Write-Host "Verification process completed!" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Make sure to clean up the Docker container
    docker stop payment-distributor-verifier 2>&1 | Out-Null
    docker rm payment-distributor-verifier 2>&1 | Out-Null
}