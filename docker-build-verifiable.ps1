# Docker Build Script for Payment Distributor Smart Contract
# This script builds a verifiable Solana contract without Anchor using Docker

param (
    [string]$action = "build",
    [string]$ProgramKeypairPath = "keypairs/program-keypair.json",
    [switch]$ReuseKeypair
)

# Set the current directory to the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Function to display help
function Show-Help {
    Write-Host "Docker Build Script for Payment Distributor Smart Contract (Verifiable Build, No Anchor)"
    Write-Host "Usage: .\docker-build.ps1 [action]"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  build    - Build the verifiable smart contract (default)"
    Write-Host "  clean    - Clean the build artifacts"
    Write-Host "  shell    - Open a shell in the Docker container"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\docker-build.ps1 build"
    Write-Host "  .\docker-build.ps1 shell"
}

# Function to build the Docker image
function Build-DockerImage {
    Write-Host "Building Docker image with pinned Solana BPF toolchain for verifiable build..."
    
    # Create a temporary Dockerfile with pinned versions
    $tempDockerfile = [System.IO.Path]::GetTempFileName()
    
    @'
FROM ubuntu:24.04

WORKDIR /app

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y build-essential pkg-config libssl-dev libudev-dev git curl binutils ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Rust with a specific version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Solana CLI and toolchain - using Anza stable channel (latest stable version)
# Split into two commands to ensure PATH is updated before running solana-install
RUN sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"
RUN solana --version

# Keep container running
CMD ["tail", "-f", "/dev/null"]
'@ | Set-Content $tempDockerfile
    
    # Build the Docker image
    docker build -t payment-distributor-builder -f $tempDockerfile .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error building Docker image" -ForegroundColor Red
        exit 1
    }
    
    Remove-Item $tempDockerfile
}

# Function to start the Docker container
function Start-DockerContainer {
    Write-Host "Starting Docker container..."
    docker run -d --name payment-distributor-builder -v ${PWD}:/app payment-distributor-builder
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error starting Docker container" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 2
}

# Function to build the smart contract with verifiable process
function Build-SmartContract {
    # Generate or use existing program keypair
    Write-Host "Setting up program keypair..."
    
    # Ensure the keypairs directory exists
    $keypairsDir = Split-Path -Parent $ProgramKeypairPath
    if (-not (Test-Path $keypairsDir)) {
        New-Item -Path $keypairsDir -ItemType Directory -Force | Out-Null
    }
    
    if ($ReuseKeypair -and (Test-Path $ProgramKeypairPath)) {
        Write-Host "Reusing existing program keypair at $ProgramKeypairPath" -ForegroundColor Yellow
    } else {
        # If the keypair exists and we're not explicitly reusing it, remove it first
        if (Test-Path $ProgramKeypairPath) {
            Write-Host "Removing existing program keypair at $ProgramKeypairPath" -ForegroundColor Yellow
            Remove-Item $ProgramKeypairPath -Force
        }
        
        Write-Host "Generating new program keypair at $ProgramKeypairPath" -ForegroundColor Green
        solana-keygen new --no-passphrase -o $ProgramKeypairPath
        Write-Host "Generated new program keypair" -ForegroundColor Green
    }
    
    # Get the program ID
    $programId = solana address -k $ProgramKeypairPath
    Write-Host "Program ID: $programId"
    
    # Update the program ID in the contract
    Write-Host "Updating program ID in contract..."
    $contractRsPath = "contract/contract.rs"
    
    if (Test-Path $contractRsPath) {
        $contractRsContent = Get-Content $contractRsPath -Raw
        
        # Simple string replacement without regex
        $oldProgramIdStart = 'declare_id!("'
        $oldProgramIdEnd = '")'
        
        $startPos = $contractRsContent.IndexOf($oldProgramIdStart)
        if ($startPos -ge 0) {
            $startPos += $oldProgramIdStart.Length
            $endPos = $contractRsContent.IndexOf($oldProgramIdEnd, $startPos)
            if ($endPos -ge 0) {
                $oldProgramId = $contractRsContent.Substring($startPos, $endPos - $startPos)
                Write-Host "Found program ID in contract.rs: $oldProgramId"
                
                $newContent = $contractRsContent.Replace(
                    "$oldProgramIdStart$oldProgramId$oldProgramIdEnd",
                    "$oldProgramIdStart$programId$oldProgramIdEnd"
                )
                
                Set-Content -Path $contractRsPath -Value $newContent
                Write-Host "Updated program ID in $contractRsPath"
            } else {
                Write-Host "Could not find end of program ID in $contractRsPath" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Could not find program ID declaration in $contractRsPath" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Contract file not found at $contractRsPath" -ForegroundColor Red
        exit 1
    }
    Write-Host "Building verifiable smart contract for Solana BPF target..."
    
    # Verify Solana version
    $solanaVersion = docker exec -t payment-distributor-builder bash -c "solana --version" 2>&1
    Write-Host "Using Solana version: $solanaVersion"
    
    # Check for contract file
    if (-not (Test-Path "contract/contract.rs")) {
        Write-Host "Error: contract.rs not found in contract directory" -ForegroundColor Red
        exit 1
    }
    
    # Copy contract to container
    docker cp "contract/contract.rs" "payment-distributor-builder:/app/src/lib.rs"
    
    # Create a temporary Cargo.toml with pinned dependencies
    $tempCargoFile = [System.IO.Path]::GetTempFileName()
    @"
[package]
name = "payment-distributor"
version = "0.1.0"
description = "Payment distribution smart contract for Solana"
edition = "2021"

[lib]
crate-type = ["cdylib", "lib"]
name = "payment_distributor"
path = "src/lib.rs"

[dependencies]
solana-program = "2.2.0"  # Match your stable CLI version
solana-security-txt = "1.1.1"  # Latest stable version

[profile.release]
opt-level = "z"
lto = "fat"
codegen-units = 1
panic = "abort"
strip = true
overflow-checks = true
incremental = false
debug = false
"@ | Set-Content $tempCargoFile
    
    docker cp $tempCargoFile "payment-distributor-builder:/app/Cargo.toml"
    Remove-Item $tempCargoFile
    
    # Create src directory (contract is already copied to /app/src/lib.rs)
    docker exec -t payment-distributor-builder bash -c "mkdir -p /app/src"
    
    # Build the contract
    Write-Host "Building with cargo build-sbf in release mode..."
    docker exec -t payment-distributor-builder bash -c "cd /app && cargo build-sbf --manifest-path=Cargo.toml --sbf-out-dir=target/deploy -- --locked"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error building smart contract with cargo build-bpf" -ForegroundColor Red
        exit 1
    }
    
    # Generate a hash for verification
    Write-Host "Generating build hash for verification..."
    docker exec -t payment-distributor-builder bash -c "sha256sum /app/target/deploy/payment_distributor.so > /app/target/deploy/payment_distributor.so.sha256"
    
    # Copy artifacts back to host
    New-Item -Path "./target/deploy" -ItemType Directory -Force | Out-Null
    docker cp "payment-distributor-builder:/app/target/deploy/payment_distributor.so" "./target/deploy/payment_distributor.so"
    docker cp "payment-distributor-builder:/app/target/deploy/payment_distributor.so.sha256" "./target/deploy/payment_distributor.so.sha256"
    docker cp "payment-distributor-builder:/app/target/deploy/payment_distributor.so" "./payment_distributor.so"
    
    # Display build info
    Write-Host "Build artifacts copied to ./target/deploy/ and ./payment_distributor.so"
    $hash = Get-Content "./target/deploy/payment_distributor.so.sha256"
    Write-Host "Build hash: $hash" -ForegroundColor Green
    
    # Optional: Get program ID
    if (Test-Path "target/deploy/payment_distributor-keypair.json") {
        try {
            $programId = solana address -k target/deploy/payment_distributor-keypair.json
            Write-Host "Program ID: $programId" -ForegroundColor Green
        } catch {
            Write-Host "WARNING: Could not get program ID. Generate with 'solana-keygen new -o target/deploy/payment_distributor-keypair.json'" -ForegroundColor Yellow
        }
    } else {
        Write-Host "WARNING: No keypair found. Generate with 'solana-keygen new -o target/deploy/payment_distributor-keypair.json'" -ForegroundColor Yellow
    }
    
    Write-Host "Verifiable smart contract built successfully" -ForegroundColor Green
    Write-Host "Verify the build using 'solana-verify' or by comparing the hash with the on-chain program."
}

# Function to clean build artifacts
function Clean-BuildArtifacts {
    Write-Host "Cleaning build artifacts..."
    docker exec -t payment-distributor-builder bash -c "rm -rf /app/target/deploy/*"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error cleaning build artifacts" -ForegroundColor Red
        exit 1
    }
    Write-Host "Build artifacts cleaned" -ForegroundColor Green
}

# Function to open a shell in the Docker container
function Open-DockerShell {
    Write-Host "Opening shell in Docker container..."
    docker exec -it payment-distributor-builder bash
}

# Function to stop the Docker container
function Stop-DockerContainer {
    Write-Host "Stopping Docker container..."
    docker stop payment-distributor-builder | Out-Null
    docker rm payment-distributor-builder | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error stopping Docker container" -ForegroundColor Red
        exit 1
    }
}

# Main script logic
try {
    switch ($action) {
        "help" {
            Show-Help
        }
        "build" {
            Build-DockerImage
            Start-DockerContainer
            Build-SmartContract
            Stop-DockerContainer
        }
        "clean" {
            Start-DockerContainer
            Clean-BuildArtifacts
            Stop-DockerContainer
        }
        "shell" {
            Start-DockerContainer
            Open-DockerShell
            Stop-DockerContainer
        }
        default {
            Write-Host "Unknown action: $action" -ForegroundColor Red
            Show-Help
            exit 1
        }
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}
finally {
    docker stop payment-distributor-builder | Out-Null
    docker rm payment-distributor-builder | Out-Null
}

Write-Host "Done!" -ForegroundColor Green