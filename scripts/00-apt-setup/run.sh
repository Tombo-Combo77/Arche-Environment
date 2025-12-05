#!/bin/bash
set -e

echo "=========================================="
echo "APT Setup - Configuring Package Sources"
echo "=========================================="

# This script configures apt sources for the Ubuntu repositories
# The default Tegra rootfs has minimal sources and is missing many packages

# Set up chroot environment properly for package operations
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C
export LANGUAGE=C
export LANG=C

# Prevent services from starting during package installation
echo "Configuring dpkg to prevent service starts..."
cat > /usr/sbin/policy-rc.d << 'EOF'
#!/bin/sh
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

# Prevent only service start/stop operations, allow enable/disable
if [ ! -f /bin/systemctl.orig ]; then
    mv /bin/systemctl /bin/systemctl.orig 2>/dev/null || true
    cat > /bin/systemctl << 'EOF'
#!/bin/bash
# Wrapper for systemctl in chroot environment
case "$1" in
    start|stop|restart|reload)
        echo "systemctl $@ (skipped in chroot - service will start on boot)"
        exit 0
        ;;
    enable|disable)
        # Allow enable/disable - these just create/remove symlinks
        exec /bin/systemctl.orig "$@"
        ;;
    *)
        exec /bin/systemctl.orig "$@"
        ;;
esac
EOF
    chmod +x /bin/systemctl
fi

echo "Setting up Ubuntu package repositories..."

# Backup existing sources.list and sources.list.d
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
fi

if [ -d /etc/apt/sources.list.d ]; then
    cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.backup
fi

# Remove problematic NVIDIA Jetson repositories that cause release file errors
echo "Removing problematic NVIDIA Jetson repositories..."
rm -f /etc/apt/sources.list.d/nvidia-l4t-apt-source.list 2>/dev/null || true
rm -f /etc/apt/sources.list.d/jetson.list 2>/dev/null || true
find /etc/apt/sources.list.d/ -name "*nvidia*" -delete 2>/dev/null || true
find /etc/apt/sources.list.d/ -name "*jetson*" -delete 2>/dev/null || true

# Determine Ubuntu version
UBUNTU_VERSION=$(lsb_release -cs 2>/dev/null || echo "jammy")
echo "Detected Ubuntu version: ${UBUNTU_VERSION}"

# Create comprehensive sources.list
cat > /etc/apt/sources.list << EOF
# Ubuntu Main Repositories
deb http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION} main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION} main restricted universe multiverse

# Ubuntu Security Updates
deb http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-security main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-security main restricted universe multiverse

# Ubuntu Updates
deb http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-updates main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-updates main restricted universe multiverse

# Ubuntu Backports
deb http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
deb-src http://ports.ubuntu.com/ubuntu-ports/ ${UBUNTU_VERSION}-backports main restricted universe multiverse
EOF

echo "✓ Configured Ubuntu package repositories"

# Clean apt cache to remove any cached problematic repository data
echo "Cleaning apt cache..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# Update package lists with error handling
echo "Updating package lists..."
export DEBIAN_FRONTEND=noninteractive

# Try to update, and if it fails due to repository issues, continue anyway
if ! apt-get update; then
    echo "⚠ Initial apt update failed, trying again with --allow-releaseinfo-change..."
    apt-get update --allow-releaseinfo-change || echo "⚠ Some repositories may be unavailable, continuing..."
fi

echo "✓ Package lists updated successfully"

# Install essential packages that might be missing
echo "Installing essential packages..."

# Install packages with chroot-friendly options
apt-get install -y --no-install-recommends \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    docker.io \
    lsb-release

echo "✓ Essential packages installed"

# Restore original systemctl if we modified it
if [ -f /bin/systemctl.orig ]; then
    mv /bin/systemctl.orig /bin/systemctl
fi

# Remove policy-rc.d
rm -f /usr/sbin/policy-rc.d

echo "=========================================="
echo "APT Setup completed successfully!"
echo "Available repositories:"
echo "  - Main (officially supported software)"
echo "  - Universe (community maintained software)"
echo "  - Multiverse (software with licensing restrictions)"
echo "  - Security updates"
echo "  - Regular updates"
echo "  - Backports"
echo "=========================================="