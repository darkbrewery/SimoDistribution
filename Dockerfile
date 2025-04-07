# Use Ubuntu 24.04 as the base image (includes GLIBC 2.39)
FROM ubuntu:24.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    libudev-dev \
    git \
    curl \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# Install Rust with a specific version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.80.1
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Solana CLI and toolchain - pinned to version 1.18.26 for verifiability
RUN sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)" && \
    /root/.local/share/solana/install/active_release/bin/solana-install init 1.18.26
ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# Set up working directory
WORKDIR /app

# Keep container running for PowerShell script interaction
CMD ["tail", "-f", "/dev/null"]