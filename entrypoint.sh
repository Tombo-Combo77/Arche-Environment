#!/bin/bash
set -ex

echo "=========================================="
echo "Jetson OS Builder - Provisioning Pipeline"
echo "=========================================="
echo "Board: ${BOARD}"
echo "Flash Command: ${FLASH_CMD}"
echo "Default User: ${DEFAULT_USERNAME}"
echo "=========================================="




# Set working directory
WORK_DIR="/workspace/Linux_for_Tegra"
ROOTFS_DIR="${WORK_DIR}/rootfs"

# Verify BSP is present
if [ ! -d "${WORK_DIR}" ]; then
    echo "ERROR: BSP not found. This should have been set up during Docker build."
    exit 1
fi

# Create default user in rootfs
pushd .
cd $WORK_DIR
echo "Creating default user account..."
./tools/l4t_create_default_user.sh -u "${DEFAULT_USERNAME}" -p "${DEFAULT_PASSWORD}" -a --accept-license
popd

# Set up qemu for cross-architecture chroot
echo "[1/3] Setting up cross-architecture chroot environment..."
sudo cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"

# Run customization scripts in numerical order
echo "[2/3] Running customization scripts..."
SCRIPT_DIR="/workspace/scripts"
ROOTFS_DIR="/workspace/Linux_for_Tegra/rootfs"

echo "  -> Preparing chroot environment..."

cleanup_chroot_mounts() {
    echo "  -> Cleaning up chroot mounts..."
    sudo umount "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/dev"     2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/proc"    2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/sys"     2>/dev/null || true
    sudo umount "${ROOTFS_DIR}/etc/resolv.conf" 2>/dev/null || true
}
trap cleanup_chroot_mounts EXIT

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

for script_dir in $(ls -d "${SCRIPT_DIR}"/*/ 2>/dev/null | sort); do
    script_name="$(basename "${script_dir}")"
    run_script="${script_dir}/run.sh"

    if [ -f "${run_script}" ]; then
        echo "  -> Executing ${script_name}..."

        # Copy the script into the rootfs
        sudo rm -rf "${ROOTFS_DIR}/tmp/${script_name}"
        sudo cp -r "${script_dir}" "${ROOTFS_DIR}/tmp/"

        # Execute within chroot
        sudo chroot "${ROOTFS_DIR}" /bin/bash -c "cd /tmp/${script_name} && bash run.sh"

        # Clean up
        sudo rm -rf "${ROOTFS_DIR}/tmp/${script_name}"

        echo "  -> ${script_name} completed successfully"
    else
        echo "  -> Warning: ${script_name} has no run.sh, skipping..."
    fi
done

echo "Customization scripts completed."
cleanup_chroot_mounts
# Clean up qemu binary
sudo rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

# Flash the device
echo "[3/3] Ready to flash device..."
echo "Flash command: ${FLASH_CMD}"

cd "${WORK_DIR}"
exec bash -lc "$FLASH_CMD"

echo ""
echo "=========================================="
echo "Flashing completed successfully!"
echo "=========================================="
