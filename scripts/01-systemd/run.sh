#!/bin/bash
set -e

echo "=========================================="
echo "01-systemd: Installing Docker"
echo "=========================================="

# Install prerequisites
echo "Installing Docker prerequisites..."
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
echo "Installing Docker Engine..."
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Enable Docker service
echo "Enabling Docker service..."
systemctl enable docker
systemctl enable containerd

# Verify installation
if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker installed successfully"
    docker --version
else
    echo "✗ Docker installation failed"
    exit 1
fi

echo "Docker installation completed."
