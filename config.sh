# Jetson OS Builder Configuration
# This file contains all configuration variables for the build process

# JetPack and L4T Version Configuration
export JETPACK_VERSION="6.0"
export L4T_VERSION="36.3.0"

# Download URLs (update these for different JetPack versions)
export BSP_URL="https://developer.nvidia.com/downloads/embedded/L4T/r36_Release_v3.0/release/Jetson_Linux_R36.3.0_aarch64.tbz2"
export ROOTFS_URL="https://developer.nvidia.com/downloads/embedded/L4T/r36_Release_v3.0/release/Tegra_Linux_Sample-Root-Filesystem_R36.3.0_aarch64.tbz2"

# Default user configuration
export DEFAULT_USERNAME="Arche"
export DEFAULT_PASSWORD="Arche"

# Development mode configuration
export DEVELOPMENT_MODE="false"  # Set to "false" for production builds

# Target board configuration
export BOARD="jetson-orin-nano-devkit"
export FLASH_CMD='sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 \
  -c tools/kernel_flash/flash_l4t_t234_nvme.xml \
  -p "-c bootloader/generic/cfg/flash_t234_qspi.xml" \
  --showlogs --network usb0 \
  jetson-orin-nano-devkit internal'

# export FLASH_CMD="sudo ./flash.sh jetson-orin-nano-devkit nvme0n1p1"

# Workspace directories
export WORKSPACE_DIR="$(pwd)"
export SCRIPTS_DIR="${WORKSPACE_DIR}/scripts"
export DOWNLOAD_DIR="${WORKSPACE_DIR}/downloads"

# Use native Linux filesystem for extraction to avoid WSL symlink issues
export EXTRACT_DIR="/home/$SUDO_USER"
export NATIVE_WORK_DIR="${EXTRACT_DIR}/jetson-build"
export WORK_DIR="${NATIVE_WORK_DIR}/Linux_for_Tegra"
export ROOTFS_DIR="${WORK_DIR}/rootfs"

# Create download directory if it doesn't exist
mkdir -p "${DOWNLOAD_DIR}"

echo "Configuration loaded:"
echo "  JetPack Version: ${JETPACK_VERSION}"
echo "  L4T Version: ${L4T_VERSION}"
echo "  Default User: ${DEFAULT_USERNAME}"
echo "  Target Board: ${BOARD}"
echo "  Development Mode: ${DEVELOPMENT_MODE}"
echo "  Workspace: ${WORKSPACE_DIR}"