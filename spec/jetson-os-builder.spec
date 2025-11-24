Title: Jetson Provisioning & Flashing Pipeline Specification

1. Overview

   This specification defines a reproducible, one-shot provisioning and flashing pipeline for NVIDIA Jetson devices (Orin Nano Super class) built and executed from an x86 Windows workstation or Linux environment.
   All provisioning occurs inside a Linux environment running under WSL2 and using Docker to flash the devices and build the rootfs.
   Rootfs customization is performed via cross-architecture chroot using qemu-user-static and binfmt_misc.
   Final flashing uses NVIDIA's standard flash scripts.

2. Goals

- Single-command (one-shot) flashing of a fully customized image.

- No post-flash manual steps; device is usable at first boot with pre-configured user account.

- Fully reproducible builds under version control.

- Works from any x86 Windows machine without dedicated Ubuntu hardware via the use of containers.

- Efficient build caching - BSP setup happens once during image build, not on every run.

3. High-Level Method

- WSL2 provides a Linux environment capable of running Docker.

- Docker container based on Ubuntu 24.04 (aligned with JetPack 7) provides the build environment.

- NVIDIA L4T BSP and base rootfs are downloaded and unpacked during Docker image build time (cached in image layers).

- NVIDIA binaries are applied to the rootfs via apply_binaries.sh during image build.

- Default user account is created via l4t_create_default_user.sh during image build.

- At runtime, rootfs is customized via cross-architecture chroot using qemu-aarch64-static and binfmt_misc.

- Customization scripts (provided by the user) modify the ARM root filesystem within the chroot environment (install packages, enable/disable services, add configs, add applications).

- NVIDIA's flash.sh or l4t_initrd_flash.sh is executed to flash the final customized image directly to the target device via USB recovery mode.

4. Repository Layout
    /scripts/
        00-test-setup/
            run.sh
        01-systemd/
            run.sh
        (additional numbered directories)
    /spec/
        jetson-os-builder.spec
    docker-compose.yml
    Dockerfile
    entrypoint.sh
    README.md

5. BSP and Rootfs Management

   BSP and rootfs are downloaded during the Docker image build phase (not at runtime).
   This provides:
   - Faster container startup (download only happens once)
   - Docker layer caching (rebuild is fast if BSP version hasn't changed)
   - Consistent build environment across all runs
   
   Version configuration is set via build args in docker-compose.yml:
   - JETPACK_VERSION (default: 7.0)
   - L4T_VERSION (default: 37.0.0)
   - BSP_URL and ROOTFS_URL (download links)

6. User Configuration

   Default user account credentials are configured in docker-compose.yml:
   - DEFAULT_USERNAME (default: Arche)
   - DEFAULT_PASSWORD (default: Arche)
   
   Board and flash command are set as runtime environment variables:
   - BOARD (e.g., jetson-orin-nano-devkit)
   - FLASH_CMD (e.g., flash.sh jetson-orin-nano-devkit internal)

7. Build Phase (Dockerfile)
   
   During `docker-compose build`:
   1. Install essential packages (qemu-user-static, binfmt-support, wget, etc.)
   2. Download and extract NVIDIA L4T BSP
   3. Download and extract sample rootfs
   4. Run apply_binaries.sh to apply NVIDIA binaries to rootfs
   5. Run l4t_create_default_user.sh to create default user account
   6. Copy customization scripts and entrypoint into image
   
   Result: Docker image contains a ready-to-customize rootfs with NVIDIA binaries applied.

8. Runtime Phase (entrypoint.sh)
   
   During `docker-compose up`:
   1. Verify BSP is present (should be from build phase)
   2. Copy qemu-aarch64-static into rootfs for ARM emulation
   3. Run user customization scripts in numerical order within ARM chroot environment
   4. Clean up qemu binary
   5. Wait for user confirmation
   6. Execute flash command to write image to Jetson device
   
   Scripts are executed in sorted order (00-*, 01-*, 02-*, etc.)

9. Customization Scripts

   Users add scripts in /scripts directory using this structure:
   
   /scripts/NN-description/run.sh
   
   Where NN is a two-digit number (00, 01, 02, etc.) that determines execution order.
   Each run.sh executes inside the ARM chroot environment and has full access to apt, systemctl, and other ARM binaries.
   
   Example scripts:
   - 00-test-setup/run.sh: Install basic packages (cowsay, vim, etc.)
   - 01-systemd/run.sh: Install and configure Docker

10. Cross-Architecture Chroot Mechanism

    The system uses QEMU user-mode emulation to run ARM binaries on x86:
    - qemu-user-static provides ARM64 emulation
    - binfmt_misc kernel feature automatically invokes QEMU for ARM binaries
    - qemu-aarch64-static is copied into the rootfs before chroot
    - When chroot executes ARM binaries, the kernel transparently uses QEMU
    - From inside the chroot, the environment appears as native ARM64
    
    This allows full customization of the Jetson rootfs without requiring ARM hardware.

11. Hardware Requirements

    - x86 Windows workstation with WSL2 enabled
    - Docker Desktop for Windows (with WSL2 backend)
    - USB connection to Jetson device
    - Jetson device in recovery mode during flashing

12. Usage Workflow

    1. Add customization scripts to /scripts directory (optional)
    2. Modify docker-compose.yml if different JetPack version or credentials needed (optional)
    3. Run `docker-compose build` to create the image with BSP (one-time, cached)
    4. Connect Jetson device in recovery mode
    5. Run `docker-compose up` to customize and flash
    6. Press Enter when prompted to begin flashing
    7. Wait for completion - device boots with all customizations applied


1. Overview

   This specification defines a reproducible, one-shot provisioning and flashing pipeline for NVIDIA Jetson devices (Orin Nano Super class) built and executed from an x86 Windows workstation or linux env.
   All provisioning occurs inside a Linux environment running under WSL2 and using docker to flash the devices and build the rootfs.
   Rootfs customization is performed via cross-architecture chroot using qemu-user-static.
   Final flashing uses NVIDIA’s standard flash scripts.

2. Goals

- Single-command (one-shot) flashing of a fully customized image.

- No post-flash manual steps; device is usable at first boot.

- Fully reproducible builds under version control.

- Works from any x86 Windows machine without dedicated Ubuntu hardware via the use of containers.

3. High-Level Method

- WSL2 provides a Linux environment capable of running Docker or native Bash.

- NVIDIA L4T BSP and base rootfs are downloaded and unpacked inside a running x86 container. (version based on arguments from the user or defaults)

- Rootfs is customized by performing a cross-architecture chroot within the container using qemu-aarch64-static and binfmt_misc.

- Customization scripts modify the ARM root filesystem (install packages, enable/disable services, add configs, add our applications). These are provided to the container and the chroot from the repository, the structure is specified below.

3. NVIDIA’s flash.sh or l4t_initrd_flash.sh is executed inside the x86 container, flashing the final customized image directly to the target device via USB recovery mode.

- the specific flash command is also provided as an arg or default

13. Repository Layout
    /scripts
    docker-compose.yml
    Dockerfile
    .env
    entrypoint.sh
    README.md

5. BSP and Rootfs Requirements
    These are downloaded at the container runtime, based on the arguments they provide. 
    This is to reduce permanent storage on device. The version is set in the env.sh

6. Detailed Steps and Responsibilities
    In order to run, the user must populate two things:
    
    1. The version of jetpack and the flash command within .env

    2. any scripts that they would like to be run on the extracted (and applied binaries) rootfs, within the scripts directory

    once these are populated, the container is simply built using the docker compose, and then the user must start the container to get it running. 

    the container's OS version will default to Ubuntu 24.04, in line with jetpack 7.

    The container will hold the pre-modified rootfs within it, running the scripts and the flash command on runtime on the chrooted rootfs. 

    from a hardware standpoint, all the user will need to do is to plug up a Jetson in recovery mode, and follow through
