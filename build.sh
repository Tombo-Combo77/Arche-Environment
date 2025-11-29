#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Jetson OS Builder - Build Phase"
echo "=========================================="
echo "Target Board: ${BOARD}"
echo "Customizing rootfs with cross-architecture chroot"
echo "=========================================="

# Verify staging was completed
if [ ! -d "${WORK_DIR}" ] || [ ! -d "${ROOTFS_DIR}" ]; then
    echo "ERROR: Staging not found. Please run './stage.sh' first."
    exit 1
fi

if [ ! -f "${WORK_DIR}/apply_binaries.sh" ]; then
    echo "ERROR: BSP not properly staged. Please run './stage.sh' first."
    exit 1
fi

# Check if scripts directory exists and has content
if [ ! -d "${SCRIPTS_DIR}" ]; then
    echo "No scripts directory found. Creating empty one..."
    mkdir -p "${SCRIPTS_DIR}"
    echo "Add customization scripts to ${SCRIPTS_DIR} and re-run build.sh"
    exit 0
fi

# Count available scripts
SCRIPT_COUNT=$(find "${SCRIPTS_DIR}" -maxdepth 1 -type d -name "*-*" | wc -l)
if [ "${SCRIPT_COUNT}" -eq 0 ]; then
    echo "No customization scripts found in ${SCRIPTS_DIR}"
    echo "Add scripts in format: NN-description/run.sh"
    echo "Skipping customization phase."
    exit 0
fi

echo "Found ${SCRIPT_COUNT} customization script(s) to execute"

# Set up cleanup function
cleanup_chroot_mounts() {
    echo "Cleaning up chroot mounts..."
    sudo umount "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/dev"     2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/proc"    2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/sys"     2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/etc/resolv.conf" 2>/dev/null || true
    sudo rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static" 2>/dev/null || true
}

# Register cleanup on exit
trap cleanup_chroot_mounts EXIT

# Set up qemu for cross-architecture chroot
echo "Setting up cross-architecture chroot environment..."
sudo cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"
echo "✓ QEMU ARM64 emulator copied to rootfs"

# Prepare chroot environment
echo "Preparing chroot environment..."

# Ensure mount points exist
sudo mkdir -p \
    "${ROOTFS_DIR}/dev" \
    "${ROOTFS_DIR}/dev/pts" \
    "${ROOTFS_DIR}/proc" \
    "${ROOTFS_DIR}/sys" \
    "${ROOTFS_DIR}/etc" \
    "${ROOTFS_DIR}/tmp"

# Bind host pseudo-filesystems into rootfs
sudo mount --bind /dev        "${ROOTFS_DIR}/dev"
sudo mount --bind /dev/pts    "${ROOTFS_DIR}/dev/pts" || true
sudo mount --bind /proc       "${ROOTFS_DIR}/proc"
sudo mount --bind /sys        "${ROOTFS_DIR}/sys"

# Bind host DNS config into chroot
if [ -f /etc/resolv.conf ]; then
    sudo rm -f "${ROOTFS_DIR}/etc/resolv.conf"
    sudo touch "${ROOTFS_DIR}/etc/resolv.conf"
    sudo mount --bind /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf"
fi

echo "✓ Chroot environment prepared"

# Execute customization scripts in numerical order
echo "Executing customization scripts..."

for script_dir in $(find "${SCRIPTS_DIR}" -maxdepth 1 -type d -name "*-*" | sort); do
    script_name="$(basename "${script_dir}")"
    run_script="${script_dir}/run.sh"

    if [ -f "${run_script}" ]; then
        echo ""
        echo "→ Executing ${script_name}..."

        # Copy the script into the rootfs
        sudo rm -rf "${ROOTFS_DIR}/tmp/${script_name}"
        sudo cp -r "${script_dir}" "${ROOTFS_DIR}/tmp/"
        
        # Make the script executable
        sudo chmod +x "${ROOTFS_DIR}/tmp/${script_name}/run.sh"

        # Execute within chroot
        if sudo chroot "${ROOTFS_DIR}" /bin/bash -c "cd /tmp/${script_name} && bash run.sh"; then
            echo "✓ ${script_name} completed successfully"
        else
            echo "✗ ${script_name} failed!"
            cleanup_chroot_mounts
            exit 1
        fi

        # Clean up script from rootfs
        sudo rm -rf "${ROOTFS_DIR}/tmp/${script_name}"
    else
        echo "⚠ Warning: ${script_name} has no run.sh, skipping..."
    fi
done

# Cleanup is handled by trap
echo ""
echo "=========================================="
echo "Build phase completed successfully!"
echo "=========================================="
echo ""
echo "Rootfs customization complete: ${ROOTFS_DIR}"
echo "Executed ${SCRIPT_COUNT} customization script(s)"
echo ""
echo "Next step:"
echo "  ./flash.sh - Flash the customized image to device"
echo "               (connect Jetson in recovery mode first)"
echo ""