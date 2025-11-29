# Arche-Environment

A reproducible, three-phase provisioning and flashing pipeline for NVIDIA Jetson devices, built and executed from an Ubuntu 22.04 virtual machine or native Linux environment.

## Overview

This project enables you to:
- Flash fully customized Jetson images using a clear three-step process
- Create reproducible builds under version control
- Customize the Jetson rootfs using cross-architecture emulation
- Deploy Jetson devices ready-to-use with pre-configured user accounts and applications

The pipeline uses a three-phase approach: **staging** (prepare BSP), **building** (customize rootfs), and **flashing** (deploy to device). All customization occurs via cross-architecture chroot using QEMU, allowing you to modify ARM64 Jetson rootfs from your x86_64 development machine.
## Features

- **Three-phase process**: Clear separation of staging, building, and flashing phases
- **Pre-configured user account**: Device boots ready-to-use with default credentials
- **Efficient caching**: BSP downloads are cached locally and reused across builds
- **Cross-architecture chroot**: Full ARM emulation via QEMU for authentic customization
- **Flexible customization**: Add your own scripts to install packages, configure services, deploy applications
- **Version controlled**: All configuration in git-trackable files
- **No containers required**: Native Ubuntu environment for maximum compatibility

## Prerequisites

### Required
- Ubuntu 22.04 LTS (virtual machine or native installation)
- Minimum 20GB free disk space
- USB connection to target Jetson device
- Internet connection (for BSP downloads during staging)

### Supported Devices
- NVIDIA Jetson Orin Nano Super (8GB/4GB)
- NVIDIA Jetson Orin Nano Developer Kit
- Other Jetson Orin series devices (with configuration changes)

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/Tombo-Combo77/Arche-Environment.git
cd Arche-Environment
```

### 2. Install Dependencies
```bash
chmod +x install-dependencies.sh
./install-dependencies.sh
```

This installs all required packages for Jetson flashing including QEMU, device tree compiler, and other essential tools.

### 3. (Optional) Configure Settings
Edit `config.sh` to customize:
- JetPack/L4T version
- Default user credentials  
- Target board type
- Flash command

### 4. (Optional) Add Custom Scripts
Add customization scripts to the `scripts/` directory:
```
scripts/
  02-my-custom-setup/
    run.sh
```

Scripts run in numerical order (00, 01, 02, etc.) inside the ARM chroot environment.

### 5. Run Staging Phase
```bash
chmod +x stage.sh
./stage.sh
```

This downloads the NVIDIA L4T BSP (~2GB), extracts the rootfs, applies binaries, and creates the default user. **This step takes 15-30 minutes** but only needs to run once per JetPack version.

### 6. Run Building Phase
```bash
chmod +x build.sh
./build.sh
```

This runs your customization scripts in the ARM chroot environment. **Can be run multiple times** to test different script configurations.

### 7. Connect Your Jetson in Recovery Mode

**For Jetson Orin Nano Developer Kit:**
1. Disconnect power
2. Place jumper on pins 9-10 (FC REC and GND) of the button header
3. Connect USB-C cable to your Ubuntu machine
4. Reconnect power

Verify recovery mode:
```bash
lsusb | grep -i nvidia
```
You should see: `ID 0955:7523 NVIDIA Corp.`

### 8. Run Flashing Phase
```bash
chmod +x flash.sh
./flash.sh
```

This will:
- Verify the device is in recovery mode
- Show a summary of what will be flashed
- Prompt for confirmation before flashing
- Flash the customized image to the device

**Flashing takes 10-20 minutes.** The device will reboot automatically when complete.

### 9. Boot Your Jetson

Remove the recovery mode jumper and reboot. Your Jetson will boot with:
- Username: `Arche` (or your configured username)
- Password: `Arche` (or your configured password)
- All your customizations applied

## Configuration

All configuration is managed in the `config.sh` file:

### Change JetPack Version
```bash
export JETPACK_VERSION="7.0"
export L4T_VERSION="37.0.0"
export BSP_URL="https://developer.nvidia.com/downloads/..."
export ROOTFS_URL="https://developer.nvidia.com/downloads/..."
```

### Change Default Credentials
```bash
export DEFAULT_USERNAME="myuser"
export DEFAULT_PASSWORD="mypassword"
```

### Change Target Board
```bash
export BOARD="jetson-agx-orin-devkit"
export FLASH_CMD="sudo ./flash.sh jetson-agx-orin-devkit internal"
```

## Customization Scripts

### Script Structure
```
scripts/
  NN-description/
    run.sh
```

- `NN`: Two-digit number (00-99) determining execution order
- `description`: Brief description of what the script does
- `run.sh`: Bash script that runs inside the ARM chroot

### Example: Install Packages
`scripts/02-install-packages/run.sh`:
```bash
#!/bin/bash
set -e

apt-get update
apt-get install -y \
    python3-pip \
    git \
    vim
```

### Example: Configure Service
`scripts/03-configure-service/run.sh`:
```bash
#!/bin/bash
set -e

systemctl enable docker
systemctl enable my-custom-service

# Add user to docker group
usermod -aG docker $SUDO_USER
```

### Available Environment
Scripts run inside the ARM chroot with:
- Full `apt` access (install any ARM64 package)
- `systemctl` for service management
- File system access to modify configs
- All standard Linux utilities

## Project Structure

```
Arche-Environment/
├── config.sh                   # Main configuration (versions, credentials, board)
├── install-dependencies.sh     # Dependency installation script
├── stage.sh                   # Phase 1: Download BSP, setup rootfs
├── build.sh                   # Phase 2: Run customization scripts
├── flash.sh                   # Phase 3: Flash device
├── scripts/                   # User customization scripts
│   ├── 00-test-setup/
│   │   └── run.sh            # Example: Install basic packages
│   └── 01-systemd/
│       └── run.sh            # Example: Install Docker
├── downloads/                 # Cache directory for BSP/rootfs (created automatically)
├── Linux_for_Tegra/          # Extracted BSP (created by stage.sh)
├── spec/
│   └── jetson-os-builder.spec # Detailed specification
└── README.md                 # This file
```

## How It Works

### Staging Phase (`./stage.sh`)
1. Downloads and caches NVIDIA L4T BSP and rootfs (~2GB)
2. Extracts BSP to `Linux_for_Tegra/` directory
3. Extracts rootfs to `Linux_for_Tegra/rootfs/`
4. Runs `apply_binaries.sh` to apply NVIDIA drivers to rootfs
5. Runs `l4t_create_default_user.sh` to create default user account
6. Result: Fully prepared BSP and rootfs ready for customization

### Building Phase (`./build.sh`)
1. Copies QEMU ARM emulator into rootfs
2. Sets up chroot environment (bind mounts /dev, /proc, /sys)
3. Runs customization scripts in numerical order via `chroot`
4. Each script executes in ARM environment (via QEMU emulation)
5. Cleans up QEMU binary and unmounts chroot environment
6. Result: Customized rootfs ready for flashing

### Flashing Phase (`./flash.sh`)
1. Verifies Jetson device is connected in recovery mode
2. Shows summary of what will be flashed
3. Prompts user for confirmation
4. Executes NVIDIA flash script to write image to device
5. Reports success or failure with diagnostics

### Cross-Architecture Magic
- **QEMU user-mode emulation** translates ARM64 instructions to x86_64
- **binfmt_misc** kernel feature automatically invokes QEMU for ARM binaries
- Inside the chroot, everything appears as native ARM64
- Your customization scripts work exactly as they would on real Jetson hardware

## Troubleshooting

### "ERROR: Staging not found"
Run `./stage.sh` first to download and prepare the BSP and rootfs.

### "ERROR: Dependencies not installed"
Run `./install-dependencies.sh` to install all required packages.

### Device Not Detected in Recovery Mode
- Check USB cable connection
- Verify recovery mode jumper placement
- Run `lsusb | grep -i nvidia` to confirm device is visible
- Try a different USB port or cable

### Flash Fails
- Ensure you have the correct `BOARD` and `FLASH_CMD` in `config.sh`
- Check that the device is in recovery mode
- Verify the BSP version matches your hardware
- Try running with `sudo` if permission errors occur

### Customization Script Fails
- Test your script syntax in a regular bash shell first
- Check that all required packages are available in the chroot
- Remember: scripts run in ARM environment, not x86_64
- Use `set -x` in your script for detailed debugging output

### QEMU Emulation Issues
- Verify binfmt_misc is working: `ls /proc/sys/fs/binfmt_misc/`
- Check that qemu-aarch64-static is installed: `which qemu-aarch64-static`
- Restart binfmt-support service: `sudo systemctl restart binfmt-support`

## Advanced Usage

### Skip Customization Scripts
To flash without running scripts, temporarily rename the `scripts/` directory or run `./flash.sh` directly after staging.

### Re-stage After BSP Version Changes
```bash
./stage.sh
```
This will re-download and extract the new BSP version.

### Test Scripts Without Flashing
```bash
./stage.sh   # Once per BSP version
./build.sh   # Run multiple times to test scripts
```

### Debug Script Issues
Add debugging to your scripts:
```bash
#!/bin/bash
set -ex  # Exit on error, show commands
echo "Starting custom setup..."
# Your commands here
```

### Manual Chroot Access
For debugging, you can manually enter the chroot:
```bash
sudo cp /usr/bin/qemu-aarch64-static Linux_for_Tegra/rootfs/usr/bin/
sudo chroot Linux_for_Tegra/rootfs /bin/bash
```

## Resources

- [NVIDIA Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r36.3/DeveloperGuide/)
- [L4T Downloads](https://developer.nvidia.com/embedded/linux-tegra)
- [Jetson Forums](https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems/)
- [Full Specification](spec/jetson-os-builder.spec)

## License

This project is provided as-is for development purposes. NVIDIA software components (L4T BSP) are subject to NVIDIA's license terms.

## Contributing

Contributions welcome! Please:
- Add example customization scripts
- Test with different Jetson models
- Improve documentation
- Report issues

---

**Jetson Orin Nano Super ready-to-deploy in three clear steps. Stage once, build repeatedly, flash when ready.**