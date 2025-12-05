#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Jetson OS Builder - Staging Phase"
echo "=========================================="
echo "JetPack Version: ${JETPACK_VERSION}"
echo "L4T Version: ${L4T_VERSION}"
echo "Target Board: ${BOARD}"
echo "Default User: ${DEFAULT_USERNAME}"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then echo "ERROR: This script must be run with sudo or as root" >&2; exit 1; fi

# Check if already staged
if [ -d "${WORK_DIR}" ] && [ -d "${ROOTFS_DIR}" ] && [ -f "${WORK_DIR}/apply_binaries.sh" ]; then
    read -p "Staging appears to be already complete. Re-stage? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping staging. Use './build.sh' to customize or './flash.sh' to flash."
        exit 0
    fi
    echo "Removing existing staging area..."
    rm -rf "${WORK_DIR}"
fi

echo "Creating workspace directories..."
mkdir -p "${DOWNLOAD_DIR}"
mkdir -p "${NATIVE_WORK_DIR}"

# Download BSP if not already cached
BSP_FILENAME=$(basename "${BSP_URL}")
BSP_PATH="${DOWNLOAD_DIR}/${BSP_FILENAME}"

if [ -f "${BSP_PATH}" ]; then
    echo "BSP already cached: ${BSP_FILENAME}"
else
    echo "Downloading NVIDIA L4T BSP..."
    echo "URL: ${BSP_URL}"
    wget -O "${BSP_PATH}" "${BSP_URL}"
    echo "✓ BSP downloaded: ${BSP_FILENAME}"
fi

# Download rootfs if not already cached  
ROOTFS_FILENAME=$(basename "${ROOTFS_URL}")
ROOTFS_PATH="${DOWNLOAD_DIR}/${ROOTFS_FILENAME}"

if [ -f "${ROOTFS_PATH}" ]; then
    echo "Rootfs already cached: ${ROOTFS_FILENAME}"
else
    echo "Downloading sample rootfs..."
    echo "URL: ${ROOTFS_URL}"
    wget -O "${ROOTFS_PATH}" "${ROOTFS_URL}"
    echo "✓ Rootfs downloaded: ${ROOTFS_FILENAME}"
fi

# Extract BSP
echo "Extracting BSP to native Linux filesystem..."
cd "${NATIVE_WORK_DIR}"
sudo tar --no-same-owner -xjf "${BSP_PATH}"
echo "✓ BSP extracted to ${WORK_DIR}"

# Extract rootfs
echo "Extracting rootfs to native Linux filesystem..."
mkdir -p "${ROOTFS_DIR}"
cd "${ROOTFS_DIR}"
sudo tar --no-same-owner -xjf "${ROOTFS_PATH}"
echo "✓ Rootfs extracted to ${ROOTFS_DIR}"

# Change to BSP directory for remaining operations
cd "${WORK_DIR}"

# Apply NVIDIA binaries to rootfs
echo "Applying NVIDIA binaries to rootfs..."
sudo ./apply_binaries.sh
echo "✓ NVIDIA binaries applied"

# Create default user account
echo "Creating default user account..."
sudo ./tools/l4t_create_default_user.sh -u "${DEFAULT_USERNAME}" -p "${DEFAULT_PASSWORD}" -a --accept-license
echo "✓ Default user '${DEFAULT_USERNAME}' created"

echo ""
echo "=========================================="
echo "Staging completed successfully!"
echo "=========================================="
echo ""
echo "BSP Location: ${WORK_DIR}"
echo "Rootfs Location: ${ROOTFS_DIR}"
echo "Default User: ${DEFAULT_USERNAME}:${DEFAULT_PASSWORD}"
echo ""
echo "Next steps:"
echo "  ./build.sh - Run customization scripts"
echo "  ./flash.sh - Flash the device (after connecting in recovery mode)"
echo ""