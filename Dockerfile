FROM ubuntu:24.04

# Build arguments for BSP setup
ARG JETPACK_VERSION=7.0
ARG L4T_VERSION=37.0.0
ARG BSP_URL
ARG ROOTFS_URL
ARG DEFAULT_USERNAME=Arche
ARG DEFAULT_PASSWORD=Arche

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's|http://archive.ubuntu.com/ubuntu|https://azure.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && apt-get update

# Install essential tools for cross-architecture chroot and flashing
# 1) Base tools (should be stable)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
    openssh-server \
 && rm -rf /var/lib/apt/lists/*

# 2) Jetson-specific / “might fail” extras in a separate layer
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    device-tree-compiler \
    lbzip2 \
    nfs-kernel-server \
    sshpass \
    # add cpio/abootimg back here only if you confirm they exist on 24.04
 && rm -rf /var/lib/apt/lists/*


# Set up working directory
WORKDIR /workspace

# Download and extract NVIDIA L4T BSP
RUN echo "Downloading NVIDIA L4T BSP..." && \
    wget -O /tmp/bsp.tbz2 "${BSP_URL}" && \
    echo "Extracting BSP..." && \
    tar -xjf /tmp/bsp.tbz2 -C /workspace/ && \
    rm /tmp/bsp.tbz2

# Download and extract sample rootfs
RUN echo "Downloading sample rootfs..." && \
    wget -O /tmp/rootfs.tbz2 "${ROOTFS_URL}" && \
    echo "Extracting rootfs..." && \
    tar -xjf /tmp/rootfs.tbz2 -C /workspace/Linux_for_Tegra/rootfs && \
    rm /tmp/rootfs.tbz2

# Apply NVIDIA binaries to rootfs
RUN cd /workspace/Linux_for_Tegra && \
    echo "Applying NVIDIA binaries to rootfs..." && \
    ./apply_binaries.sh

# Create default user in rootfs
RUN cd /workspace/Linux_for_Tegra && \
    echo "Creating default user account..." && \
    ./tools/l4t_create_default_user.sh -u "${DEFAULT_USERNAME}" -p "${DEFAULT_PASSWORD}" -a --accept-license

# Copy scripts into the container
COPY scripts/ /workspace/scripts/
COPY entrypoint.sh /workspace/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /workspace/entrypoint.sh

# Make all scripts executable
RUN find /workspace/scripts -type f -name "*.sh" -exec chmod +x {} \;

# Set the entrypoint
ENTRYPOINT ["/workspace/entrypoint.sh"]
