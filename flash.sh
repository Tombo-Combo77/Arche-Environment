#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Jetson OS Builder - Flash Phase"
echo "=========================================="
echo "Target Board: ${BOARD}"
echo "Flash Command: ${FLASH_CMD}"
echo "=========================================="

# Verify staging and build were completed
if [ ! -d "${WORK_DIR}" ] || [ ! -d "${ROOTFS_DIR}" ]; then
    echo "ERROR: Staging not found. Please run './stage.sh' first."
    exit 1
fi

if [ ! -f "${WORK_DIR}/flash.sh" ]; then
    echo "ERROR: Flash script not found. BSP may not be properly staged."
    exit 1
fi

# Check for Jetson device in recovery mode
echo "Checking for Jetson device in recovery mode..."
if lsusb | grep -q "0955:"; then
    DEVICE_INFO=$(lsusb | grep "0955:" | head -1)
    echo "✓ Jetson device detected: ${DEVICE_INFO}"
else
    echo "✗ No Jetson device found in recovery mode!"
    echo ""
    echo "Please ensure:"
    echo "  1. Jetson device is connected via USB"
    echo "  2. Device is in recovery mode (force recovery jumper/button)"
    echo "  3. Device has power connected"
    echo ""
    echo "For Jetson Orin Nano Developer Kit:"
    echo "  - Power off device"
    echo "  - Place jumper on pins 9-10 (FC REC and GND)"
    echo "  - Connect USB-C to host PC"
    echo "  - Power on device"
    echo ""
    read -p "Press Enter after putting device in recovery mode, or Ctrl+C to abort..."
    
    # Check again after user confirmation
    if lsusb | grep -q "0955:"; then
        DEVICE_INFO=$(lsusb | grep "0955:" | head -1)
        echo "✓ Jetson device detected: ${DEVICE_INFO}"
    else
        echo "✗ Still no device found. Please check connections and recovery mode."
        exit 1
    fi
fi

# Verify rootfs exists and looks reasonable
if [ ! -d "${ROOTFS_DIR}/bin" ] || [ ! -d "${ROOTFS_DIR}/etc" ]; then
    echo "ERROR: Rootfs appears incomplete. Please run './build.sh' first."
    exit 1
fi

# Show summary of what will be flashed
echo ""
echo "Flash Summary:"
echo "  Source BSP: ${WORK_DIR}"
echo "  Target Board: ${BOARD}"
echo "  Flash Command: ${FLASH_CMD}"
echo "  Default User: ${DEFAULT_USERNAME}"

# Count customization scripts that were applied
if [ -d "${SCRIPTS_DIR}" ]; then
    SCRIPT_COUNT=$(find "${SCRIPTS_DIR}" -maxdepth 1 -type d -name "*-*" | wc -l)
    echo "  Customizations: ${SCRIPT_COUNT} scripts applied"
fi

echo ""
echo "⚠ WARNING: This will completely overwrite the target Jetson device!"
echo "⚠ Ensure you have the correct device connected."
echo ""

read -p "Continue with flashing? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Flashing aborted."
    exit 0
fi

# Change to BSP directory
cd "${WORK_DIR}"

echo ""
echo "Starting flash process..."
echo "This may take 10-20 minutes depending on the image size."
echo "DO NOT disconnect the device during flashing!"
echo ""

# Execute the flash command
echo "Executing: ${FLASH_CMD}"
eval "${FLASH_CMD}"

FLASH_EXIT_CODE=$?

echo ""
if [ ${FLASH_EXIT_CODE} -eq 0 ]; then
    echo "=========================================="
    echo "Flashing completed successfully!"
    echo "=========================================="
    echo ""
    echo "The Jetson device will now reboot automatically."
    echo ""
    echo "After reboot:"
    echo "  - Remove recovery mode jumper/button"
    echo "  - Allow device to boot normally"
    echo "  - Login with: ${DEFAULT_USERNAME} / ${DEFAULT_PASSWORD}"
    echo ""
    echo "Your Jetson is ready to use!"
else
    echo "=========================================="
    echo "Flashing failed!"
    echo "=========================================="
    echo ""
    echo "Flash command exited with code: ${FLASH_EXIT_CODE}"
    echo ""
    echo "Common issues:"
    echo "  - Device not in recovery mode"
    echo "  - USB connection problems"
    echo "  - Insufficient permissions (try with sudo)"
    echo "  - Wrong board configuration in config.sh"
    echo ""
    echo "Check the error messages above for more details."
    exit ${FLASH_EXIT_CODE}
fi