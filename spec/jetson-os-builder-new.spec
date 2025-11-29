Title: Jetson Provisioning & Flashing Pipeline Specification

1. Overview

   This specification defines a reproducible, three-phase provisioning and flashing pipeline for NVIDIA Jetson devices (Orin Nano Super class) built and executed from an Ubuntu 22.04 virtual machine or native Linux environment.
   The pipeline consists of three distinct phases: staging, building, and flashing.
   Rootfs customization is performed via cross-architecture chroot using qemu-user-static and binfmt_misc.
   Final flashing uses NVIDIA's standard flash scripts.

2. Goals

- Three-step process for complete control over each phase of the build.

- No post-flash manual steps; device is usable at first boot with pre-configured user account.

- Fully reproducible builds under version control.

- Works from any Ubuntu 22.04 environment without requiring containerization.

- Efficient caching - BSP downloads are cached locally and reused across builds.

3. High-Level Method

- Ubuntu 22.04 provides the native Linux environment for all operations.

- Three-phase approach: stage.sh (prepare), build.sh (customize), flash.sh (deploy).

- NVIDIA L4T BSP and base rootfs are downloaded and cached during staging phase.

- NVIDIA binaries are applied to the rootfs via apply_binaries.sh during staging.

- Default user account is created via l4t_create_default_user.sh during staging.

- During building phase, rootfs is customized via cross-architecture chroot using qemu-aarch64-static and binfmt_misc.

- Customization scripts (provided by the user) modify the ARM root filesystem within the chroot environment (install packages, enable/disable services, add configs, add applications).

- During flashing phase, NVIDIA's flash.sh or l4t_initrd_flash.sh is executed to flash the final customized image directly to the target device via USB recovery mode.

4. Repository Layout
    /scripts/
        00-test-setup/
            run.sh
        01-systemd/
            run.sh
        (additional numbered directories)
    /spec/
        jetson-os-builder.spec
    config.sh
    install-dependencies.sh
    stage.sh
    build.sh
    flash.sh
    README.md

5. BSP and Rootfs Management

   BSP and rootfs are downloaded during the staging phase and cached locally in downloads/ directory.
   This provides:
   - Local caching (downloads only happen once per version)
   - No dependency on containerization
   - Fast re-builds when only customization changes
   - Consistent build environment across all runs
   
   Version configuration is set in config.sh:
   - JETPACK_VERSION (default: 7.0)
   - L4T_VERSION (default: 37.0.0)
   - BSP_URL and ROOTFS_URL (download links)

6. User Configuration

   Default user account credentials are configured in config.sh:
   - DEFAULT_USERNAME (default: Arche)
   - DEFAULT_PASSWORD (default: Arche)
   
   Board and flash command are set in config.sh:
   - BOARD (e.g., jetson-orin-nano-devkit)
   - FLASH_CMD (e.g., sudo ./flash.sh jetson-orin-nano-devkit-super-nvme internal)

7. Staging Phase (stage.sh)
   
   During staging phase:
   1. Load configuration from config.sh
   2. Download and cache NVIDIA L4T BSP (if not already cached)
   3. Download and cache sample rootfs (if not already cached)
   4. Extract BSP to Linux_for_Tegra/ directory
   5. Extract rootfs to Linux_for_Tegra/rootfs/
   6. Run apply_binaries.sh to apply NVIDIA binaries to rootfs
   7. Run l4t_create_default_user.sh to create default user account
   
   Result: Fully prepared BSP and rootfs ready for customization.

8. Building Phase (build.sh)
   
   During building phase:
   1. Load configuration from config.sh
   2. Verify staging was completed successfully
   3. Copy qemu-aarch64-static into rootfs for ARM emulation
   4. Setup chroot environment (bind mount /dev, /proc, /sys, etc.)
   5. Run user customization scripts in numerical order within ARM chroot environment
   6. Clean up qemu binary and chroot mounts
   
   Scripts are executed in sorted order (00-*, 01-*, 02-*, etc.)

9. Flashing Phase (flash.sh)
   
   During flashing phase:
   1. Load configuration from config.sh
   2. Verify device is connected in recovery mode
   3. Display flash summary and request user confirmation
   4. Execute NVIDIA flash command to write image to Jetson device
   5. Report success or failure with helpful diagnostics

10. Customization Scripts

    Users add scripts in /scripts directory using this structure:
    
    /scripts/NN-description/run.sh
    
    Where NN is a two-digit number (00, 01, 02, etc.) that determines execution order.
    Each run.sh executes inside the ARM chroot environment and has full access to apt, systemctl, and other ARM binaries.
    
    Example scripts:
    - 00-test-setup/run.sh: Install basic packages (cowsay, vim, etc.)
    - 01-systemd/run.sh: Install and configure Docker

11. Cross-Architecture Chroot Mechanism

    The system uses QEMU user-mode emulation to run ARM binaries on x86_64:
    - qemu-user-static provides ARM64 emulation
    - binfmt_misc kernel feature automatically invokes QEMU for ARM binaries
    - qemu-aarch64-static is copied into the rootfs before chroot during build phase
    - When chroot executes ARM binaries, the kernel transparently uses QEMU
    - From inside the chroot, the environment appears as native ARM64
    
    This allows full customization of the Jetson rootfs without requiring ARM hardware.

12. Hardware Requirements

    - Ubuntu 22.04 virtual machine or native installation
    - Sufficient disk space (minimum 20GB free for BSP, rootfs, and build artifacts)
    - USB connection to Jetson device
    - Jetson device in recovery mode during flashing

13. Usage Workflow

    1. Install dependencies: `./install-dependencies.sh`
    2. Configure settings in config.sh if different JetPack version or credentials needed (optional)
    3. Add customization scripts to /scripts directory (optional)
    4. Run staging phase: `./stage.sh` (downloads BSP, sets up rootfs - one-time per version)
    5. Run building phase: `./build.sh` (applies customizations via chroot)
    6. Connect Jetson device in recovery mode
    7. Run flashing phase: `./flash.sh` (flashes device)
    8. Wait for completion - device boots with all customizations applied

14. Benefits of Three-Phase Approach

    - **Separation of Concerns**: Each phase has a distinct responsibility
    - **Development Efficiency**: Can re-run build.sh multiple times to test script changes without re-downloading BSP
    - **Debugging**: Easier to isolate issues to specific phases
    - **Flexibility**: Can skip phases if needed (e.g., flash.sh only to re-flash same image)
    - **Transparency**: User has full control and visibility into each step