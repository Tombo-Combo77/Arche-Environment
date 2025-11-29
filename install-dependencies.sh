#!/bin/bash
set -e

echo "=========================================="
echo "Installing Jetson Flashing Dependencies"
echo "=========================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root. Please run as regular user with sudo access." 
   exit 1
fi

# Update package list
echo "Updating package list..."
sudo apt-get update

# Install essential base packages
echo "Installing essential packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    curl \
    sudo \
    binutils \
    python3 \
    python3-pip \
    qemu-user-static \
    binfmt-support \
    libxml2-utils \
    udev \
    tar \
    openssh-client \
    openssh-server \
    git \
    build-essential

# Install Jetson-specific flashing tools
echo "Installing Jetson flashing tools..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    device-tree-compiler \
    abootimg \
    cpio \
    lbzip2 \
    nfs-kernel-server \
    sshpass \
    xmlstarlet \
    zstd \
    uuid-runtime \
    dosfstools \
    parted \
    gdisk \
    kpartx \
    mtd-utils \
    android-tools-adb \
    android-tools-fastboot

# Install additional utilities that may be needed
echo "Installing additional utilities..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    rsync \
    unzip \
    bc \
    flex \
    bison \
    libssl-dev \
    libncurses5-dev \
    libncursesw5-dev \
    squashfs-tools

# Clean up package cache
echo "Cleaning up package cache..."
sudo apt-get autoremove -y
sudo apt-get autoclean

# Verify QEMU setup for ARM64 emulation
echo "Verifying QEMU ARM64 emulation setup..."
if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "✓ QEMU ARM64 emulation is properly configured"
else
    echo "Setting up QEMU ARM64 emulation..."
    sudo systemctl enable binfmt-support
    sudo systemctl start binfmt-support
    
    # Register QEMU ARM64 handler if not already done
    if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:CF' | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null
    fi
    echo "✓ QEMU ARM64 emulation configured"
fi

# Verify key tools are available
echo "Verifying installation..."
command -v wget >/dev/null 2>&1 && echo "✓ wget installed" || echo "✗ wget missing"
command -v qemu-aarch64-static >/dev/null 2>&1 && echo "✓ qemu-aarch64-static installed" || echo "✗ qemu-aarch64-static missing"
command -v python3 >/dev/null 2>&1 && echo "✓ python3 installed" || echo "✗ python3 missing"
command -v dtc >/dev/null 2>&1 && echo "✓ device-tree-compiler installed" || echo "✗ device-tree-compiler missing"

echo ""
echo "=========================================="
echo "Dependencies installation completed!"
echo "=========================================="
echo ""
echo "Your Ubuntu system is now ready for Jetson flashing."
echo "You can now run:"
echo "  1. ./stage.sh    - to download and prepare BSP/rootfs"
echo "  2. ./build.sh    - to customize the rootfs"
echo "  3. ./flash.sh    - to flash the device"
echo ""