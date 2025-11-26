FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential tools for cross-architecture chroot and flashing
# 1) Base tools (should be stable)
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    curl \
    sudo \
    binutils \
    python3 \
    python3-pip \
    qemu-user-static \
    libxml2-utils \
    udev \
    tar \
    openssh-client \
    openssh-server


# 2) Jetson-specific / “might fail” extras in a separate layer
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    device-tree-compiler \
    abootimg \
    cpio \
    lbzip2 \
    nfs-kernel-server \
    sshpass \
    xmlstarlet \
    abootimg \
    zstd \
    uuid-runtime \
    dosfstools

# Set up working directory
WORKDIR /workspace

# Download and extract NVIDIA L4T BSP
ARG BSP_URL
RUN echo "Downloading NVIDIA L4T BSP..." && \
    wget -O /tmp/bsp.tbz2 "${BSP_URL}" && \
    echo "Extracting BSP..." && \
    tar -xjf /tmp/bsp.tbz2 -C /workspace/ && \
    rm /tmp/bsp.tbz2

# Download and extract sample rootfs
ARG ROOTFS_URL
RUN echo "Downloading sample rootfs..." && \
    wget -O /tmp/rootfs.tbz2 "${ROOTFS_URL}" && \
    echo "Extracting rootfs..." && \
    tar -xjf /tmp/rootfs.tbz2 -C /workspace/Linux_for_Tegra/rootfs && \
    rm /tmp/rootfs.tbz2

USER root
# Apply NVIDIA binaries to rootfs
RUN cd /workspace/Linux_for_Tegra && \
    echo "Applying NVIDIA binaries to rootfs..." && \
    ./apply_binaries.sh

# Copy scripts into the container
COPY scripts/ /workspace/scripts/
COPY entrypoint.sh /workspace/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/workspace/entrypoint.sh"]
