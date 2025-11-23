Title: Jetson Provisioning & Flashing Pipeline Specification
Version: 1.0
Owner: Thomas Cousins

1. Overview
   This specification defines a reproducible, one-shot provisioning and flashing pipeline for NVIDIA Jetson devices (Orin Nano Super class) built and executed from an x86 Windows workstation.
   All provisioning occurs inside a Linux environment running under WSL2 and docker.
   Rootfs customization is performed via cross-architecture chroot using qemu-user-static.
   Final flashing uses NVIDIA’s standard flash scripts.

2. Goals

- Single-command (one-shot) flashing of a fully customized image.

- No post-flash manual steps; device is usable at first boot.

- Fully reproducible builds under version control.

- Works from any x86 Windows machine without dedicated Ubuntu hardware.

3. High-Level Method

- WSL2 provides a Linux environment capable of running Docker or native Bash.

- NVIDIA L4T BSP and base rootfs are unpacked inside a running x86 container. (based on arguments from the user or defaults)

- Rootfs is customized by performing a cross-architecture chroot using qemu-aarch64-static and binfmt_misc.

- Customization scripts modify the ARM root filesystem (install packages, enable/disable services, add configs, add our applications). These are provided to the container and the chroot from the repository, the structure is specified below.

3. NVIDIA’s flash.sh or l4t_initrd_flash.sh is executed inside the x86 container, flashing the final customized image directly to the target device via USB recovery mode.

- the specific flash command is also provided as an arg or default

13. Repository Layout
    /provisioning
    /scripts
    01_setup_env.sh
    02_unpack_bsp.sh
    03_prepare_rootfs.sh
    04_customize_rootfs.sh
    05_finalize_rootfs.sh
    06_flash.sh
    /workspace
    build artifacts, temporary mounts, chroot staging areas

Everything under /provisioning is maintained in Git except for the downloaded BSP and rootfs.

5. BSP and Rootfs Requirements
   The NVIDIA JetPack / L4T bundle contains two major components:
6. Bootloader + device configuration: stored in the BSP tarball.
7. ARM64 root filesystem: l4t-rootfs.tar.gz.

We store these in:
/provisioning/bsp/JetPack_<version>/
/provisioning/l4trootfs/

Engineer downloads the BSP manually once. Everything after that is automated.

6. Detailed Steps and Responsibilities

6.1 Environment Setup (WSL2)
Install WSL2 with Ubuntu.
Install required tools:

* qemu-user-static
* binfmt-support
* docker.io (optional)
  Enable ARM64 emulation:
  update-binfmts --enable qemu-aarch64.

6.2 Unpack BSP and Base Rootfs
Script: 02_unpack_bsp.sh

* Unpacks NVIDIA BSP to /provisioning/bsp
* Unpacks l4trootfs.tar.gz into /provisioning/l4trootfs
* Applies NVIDIA apply_binaries.sh to merge proprietary drivers into rootfs.

6.3 Cross-Architecture Chroot
Script: 03_prepare_rootfs.sh

* Copies /usr/bin/qemu-aarch64-static into /provisioning/l4trootfs/usr/bin
* Bind-mounts /dev, /proc, /sys into rootfs so package install works.
* Verifies that running “chroot /provisioning/l4trootfs /bin/bash -c ‘uname -a’” executes under qemu.

6.4 Rootfs Customization
Script: 04_customize_rootfs.sh
Executed inside the chroot.
Tasks performed here include:

* apt-get install packages
* add/remove systemd units
* place your application stack and configs
* add user accounts
* disable unwanted services
* install Docker or Podman (if used)
* drop overlays from /provisioning/overlays into appropriate rootfs directories.

This is the only step that modifies the image.

6.5 Finalization
Script: 05_finalize_rootfs.sh

* Removes temporary mounts
* Cleans package cache
* Ensures /usr/bin/qemu-aarch64-static remains or is removed based on preference
* Prepares final flash-ready rootfs.

6.6 Flashing
Script: 06_flash.sh

* Uses NVIDIA flash.sh or l4t_initrd_flash.sh
* Points to the board config and the customized rootfs
* Requires the Jetson in recovery mode, attached to Windows and forwarded into WSL2 via usbipd
* Produces a completely flashed device with no further steps required.

7. USB Connectivity from Windows
   The engineer must attach the Jetson’s USB recovery device into WSL2 using:
   usbipd wsl attach --busid <BUS-ID>.
   The script will fail if this is not done.

8. Requirements for Success

9. Engineer must run all scripts from inside WSL2, not pure Windows.

10. Rootfs customization must only be done inside the cross-arch chroot.

11. All scripts must exit on error and print clear logs.

12. The flash script must reference the correct board configuration (exact cfg file determined per device).

13. The BSP and rootfs versions must match.

14. Outputs

* Fully customized root filesystem
* Reproducible provisioning logs
* Flashable image
* One-shot production-ready units

10. Non-Goals

* No containerized rootfs boot
* No complex initrd overlays
* No host-dependent post-configuration
* No support for flashing from pure Windows without WSL2

---

If you want, I can produce the matching /scripts skeleton (each script with comments and placeholder commands) so your engineer can copy/paste directly into the repo.
