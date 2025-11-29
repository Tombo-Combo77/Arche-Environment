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

# Target board configuration
export BOARD="jetson-orin-nano-devkit"
export FLASH_CMD="sudo ./flash.sh jetson-orin-nano-devkit-super-nvme internal"

# Workspace directories
export WORKSPACE_DIR="$(pwd)"
export WORK_DIR="${WORKSPACE_DIR}/Linux_for_Tegra"
export ROOTFS_DIR="${WORK_DIR}/rootfs"
export SCRIPTS_DIR="${WORKSPACE_DIR}/scripts"
export DOWNLOAD_DIR="${WORKSPACE_DIR}/downloads"

# Create download directory if it doesn't exist
mkdir -p "${DOWNLOAD_DIR}"

echo "Configuration loaded:"
echo "  JetPack Version: ${JETPACK_VERSION}"
echo "  L4T Version: ${L4T_VERSION}"
echo "  Default User: ${DEFAULT_USERNAME}"
echo "  Target Board: ${BOARD}"
echo "  Workspace: ${WORKSPACE_DIR}"