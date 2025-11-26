# Arche-Environment

A reproducible, one-shot provisioning and flashing pipeline for NVIDIA Jetson devices, built and executed from an x86 Windows workstation using Docker and WSL2.

## Overview

This project enables you to:
- Flash fully customized Jetson images with a single command
- Create reproducible builds under version control
- Customize the Jetson rootfs on x86 hardware using cross-architecture emulation
- Deploy Jetson devices ready-to-use with pre-configured user accounts and applications

All provisioning occurs inside a Docker container with cross-architecture support via QEMU, allowing you to modify ARM64 Jetson rootfs from your x86 development machine.

**NOTE** If you are using windows, you may need to use a tool like dos2unix in order to have the fgies be readable
## Features

- **One-shot flashing**: Single command from build to deployed device
- **Pre-configured user account**: Device boots ready-to-use with default credentials
- **Efficient caching**: BSP downloads happen once during image build, not every run
- **Cross-architecture chroot**: Full ARM emulation via QEMU for authentic customization
- **Flexible customization**: Add your own scripts to install packages, configure services, deploy applications
- **Version controlled**: All configuration in git-trackable files

## Prerequisites

### Required
- Windows 10/11 with WSL2 enabled
- Docker Desktop for Windows (with WSL2 backend enabled)
- USB connection to target Jetson device
- Internet connection (for BSP downloads during build)

### Supported Devices
- NVIDIA Jetson Orin Nano Super (8GB/4GB)
- NVIDIA Jetson Orin Nano Developer Kit
- Other Jetson Orin series devices (with configuration changes)

## Quick Start

### 0. Connect the Orin and bind USB to WSL (windows 11)
Put the orin into forced recovery mode and connect the device to your computer via the OTG port. 

If on a windows machine follow these additional steps, then follow the rest of the quick start within WSL:
  1. install `usbipd` from **within an admin cmd prompt**, and start wsl
  2. Using `usbipd list` **within an admin cmd prompt** determine which device is the Orin, and note the BUSID (note, the orin will usually have a VID starting with 0955)
  3. The USB device will need to be put into a shared state, **within the admin shell** run the following command `usbipd bind --busid "BUSID"`
  4. Run `usbipd attach --wsl --busid "BUSID"`
  5. in wsl, ensure that you can see the device with `lsusb`

### 1. Clone the Repository
```bash
git clone https://github.com/Tombo-Combo77/Arche-Environment.git
cd Arche-Environment
```

### 2. (Optional) Add Custom Scripts
Add customization scripts to the `scripts/` directory:
```
scripts/
  02-my-custom-setup/
    run.sh
```

Scripts run in numerical order (00, 01, 02, etc.) inside the ARM chroot environment.

### 3. Build the Docker Image
**NOTE: if on windows, installing docker onto your host machine will provide docker, provided you enable WSL2 based engine!**

```bash
docker-compose build
```

This downloads the NVIDIA L4T BSP (~2GB), extracts the rootfs, applies binaries, and creates the default user. **This step takes 15-30 minutes** but only needs to run once (or when you change JetPack versions).

### 4. Connect Your Jetson in Recovery Mode

**For Jetson Orin Nano Developer Kit:**
1. Disconnect power
2. Place jumper on pins 9-10 (FC REC and GND) of the button header
3. Connect USB-C cable to your PC
4. Reconnect power

Verify recovery mode:
```bash
lsusb | grep -i nvidia
```
You should see: `ID 0955:7523 NVIDIA Corp.`

### 5. Flash the Device
```bash
docker-compose up
```

The container will:
- Run your customization scripts in the ARM chroot
- Prompt you to confirm before flashing
- Flash the device when you press Enter

**Flashing takes 10-20 minutes.** The device will reboot automatically when complete.

### 6. Boot Your Jetson

Remove the recovery mode jumper and reboot. Your Jetson will boot with:
- Username: `Arche`
- Password: `Arche`
- All your customizations applied

## Configuration

### Change JetPack Version
Edit `docker-compose.yml`:
```yaml
args:
  - JETPACK_VERSION=7.0
  - L4T_VERSION=37.0.0
  - BSP_URL=https://developer.nvidia.com/downloads/...
  - ROOTFS_URL=https://developer.nvidia.com/downloads/...
```

### Change Default Credentials
Edit `docker-compose.yml`:
```yaml
args:
  - DEFAULT_USERNAME=myuser
  - DEFAULT_PASSWORD=mypassword
```

### Change Target Board
Edit `docker-compose.yml`:
```yaml
environment:
  - BOARD=jetson-agx-orin-devkit
  - FLASH_CMD=flash.sh jetson-agx-orin-devkit internal
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
├── docker-compose.yml    # Main configuration (versions, credentials, board)
├── Dockerfile           # Build instructions (downloads BSP, sets up rootfs)
├── entrypoint.sh        # Runtime script (runs customizations, flashes device)
├── scripts/             # User customization scripts
│   ├── 00-test-setup/
│   │   └── run.sh      # Example: Install basic packages
│   └── 01-systemd/
│       └── run.sh      # Example: Install Docker
├── spec/
│   └── jetson-os-builder.spec  # Detailed specification
└── README.md           # This file
```

## How It Works

### Build Phase (`docker-compose build`)
1. Starts with Ubuntu 24.04 base image
2. Installs QEMU and flashing tools
3. Downloads NVIDIA L4T BSP and rootfs (~2GB)
4. Extracts BSP and rootfs
5. Runs `apply_binaries.sh` to apply NVIDIA drivers
6. Runs `l4t_create_default_user.sh` to create default user
7. Result: Docker image with ready-to-customize rootfs

### Runtime Phase (`docker-compose up`)
1. Copies QEMU ARM emulator into rootfs
2. Runs customization scripts in numerical order via `chroot`
3. Each script executes in ARM environment (via QEMU emulation)
4. Waits for user confirmation
5. Executes NVIDIA flash script to write to device

### Cross-Architecture Magic
- **QEMU user-mode emulation** translates ARM64 instructions to x86
- **binfmt_misc** kernel feature automatically invokes QEMU for ARM binaries
- Inside the chroot, everything appears as native ARM64
- Your customization scripts work exactly as they would on real Jetson hardware

## Troubleshooting

### "ERROR: BSP not found"
The Docker image wasn't built properly. Run `docker-compose build` again.

### Device Not Detected in Recovery Mode
- Check USB cable connection
- Verify recovery mode jumper placement
- Run `lsusb | grep -i nvidia` to confirm device is visible

### Flash Fails
- Ensure you have the correct `BOARD` and `FLASH_CMD` in `docker-compose.yml`
- Check that the device is in recovery mode
- Verify the BSP version matches your hardware

### Customization Script Fails
- Test your script syntax outside the container first
- Check logs: the entrypoint shows which script failed
- Remember: scripts run in ARM environment, not x86

## Advanced Usage

### Skip Customization Scripts
To flash without running scripts, temporarily rename the `scripts/` directory.

### Rebuild After BSP Changes
```bash
docker-compose build --no-cache
```

### View Container Logs
```bash
docker-compose up 2>&1 | tee flash.log
```

### Interactive Container Access
```bash
docker-compose run --entrypoint /bin/bash jetson-os-builder
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

**Jetson Orin Nano Super ready-to-deploy in one command. Build once, flash many times.**