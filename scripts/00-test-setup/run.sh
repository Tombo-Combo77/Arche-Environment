#!/bin/bash
set -e

echo "=========================================="
echo "00-test-setup: Installing basic packages"
echo "=========================================="

# Update package lists
apt-get update

# Install test packages
echo "Installing cowsay and other essential packages..."
apt-get install -y \
    cowsay \
    curl \
    wget \
    vim \
    htop \
    net-tools

# Verify installation
if command -v cowsay >/dev/null 2>&1; then
    echo "✓ cowsay installed successfully"
    cowsay "Package installation complete!"
else
    echo "✗ cowsay installation failed"
    exit 1
fi

echo "Basic package installation completed."
