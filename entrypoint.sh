#!/bin/bash
set -e

echo "=========================================="
echo "Jetson OS Builder - Provisioning Pipeline"
echo "=========================================="
echo "Board: ${BOARD}"
echo "Flash Command: ${FLASH_CMD}"
echo "=========================================="

# Set working directory
WORK_DIR="/workspace/Linux_for_Tegra"
ROOTFS_DIR="${WORK_DIR}/rootfs"

# Verify BSP is present
if [ ! -d "${WORK_DIR}" ]; then
    echo "ERROR: BSP not found. This should have been set up during Docker build."
    exit 1
fi

# Set up qemu for cross-architecture chroot
echo "[1/3] Setting up cross-architecture chroot environment..."
sudo cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"

# Run customization scripts in numerical order
echo "[2/3] Running customization scripts..."
SCRIPT_DIR="/workspace/scripts"

for script_dir in $(ls -d ${SCRIPT_DIR}/*/ 2>/dev/null | sort); do
    script_name=$(basename "${script_dir}")
    run_script="${script_dir}/run.sh"
    
    if [ -f "${run_script}" ]; then
        echo "  -> Executing ${script_name}..."
        
        # Copy the script into the rootfs
        sudo cp -r "${script_dir}" "${ROOTFS_DIR}/tmp/"
        
        # Execute within chroot
        sudo chroot "${ROOTFS_DIR}" /bin/bash -c "cd /tmp/$(basename ${script_dir}) && bash run.sh"
        
        # Clean up
        sudo rm -rf "${ROOTFS_DIR}/tmp/$(basename ${script_dir})"
        
        echo "  -> ${script_name} completed successfully"
    else
        echo "  -> Warning: ${script_name} has no run.sh, skipping..."
    fi
done

echo "Customization scripts completed."

# Clean up qemu binary
sudo rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

# Flash the device
echo "[3/3] Ready to flash device..."
echo "Flash command: ${FLASH_CMD}"
echo ""
echo "Please ensure your Jetson device is connected in recovery mode."
echo "Press Enter to begin flashing, or Ctrl+C to cancel..."
read

cd "${WORK_DIR}"
sudo ./${FLASH_CMD}

echo ""
echo "=========================================="
echo "Flashing completed successfully!"
echo "=========================================="
