#!/bin/bash
set -e

echo "=========================================="
echo "Development Setup - Remote Access Configuration"
echo "=========================================="

# Check if development mode is enabled
if [ "${DEVELOPMENT_MODE}" != "true" ]; then
    echo "Development mode is disabled. Skipping development setup."
    exit 0
fi

# Get script directory
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
FILES_DIR="${SCRIPT_DIR}/files"

echo "Configuring development environment..."
echo "Static IP: ${DEV_STATIC_IP}"
echo "VNC Port: ${DEV_VNC_PORT}"

# Install NetworkManager for static IP configuration
echo "Installing NetworkManager..."
apt-get install -y --no-install-recommends network-manager

# Install VNC server and desktop environment
echo "Installing TigerVNC and XFCE desktop..."
apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    tigervnc-common \
    xfce4 \
    xfce4-terminal

# Install basic development tools
echo "Installing development tools..."
apt-get install -y --no-install-recommends \
    openssh-server \
    vim \
    nano \
    git \
    curl \
    wget \
    htop \
    net-tools

# Configure static IP with NetworkManager
echo "Configuring static IP..."
mkdir -p /etc/NetworkManager/system-connections
cp "${FILES_DIR}/static-ip.nmconnection" /etc/NetworkManager/system-connections/
chmod 600 /etc/NetworkManager/system-connections/static-ip.nmconnection

# Enable NetworkManager
systemctl enable NetworkManager

# Configure VNC server for default user
echo "Configuring VNC server..."
mkdir -p /home/${DEFAULT_USERNAME}/.vnc

# Set VNC password
echo "${DEV_VNC_PASSWORD}" | vncpasswd -f > /home/${DEFAULT_USERNAME}/.vnc/passwd
chmod 600 /home/${DEFAULT_USERNAME}/.vnc/passwd

# Copy VNC xstartup script
cp "${FILES_DIR}/xstartup" /home/${DEFAULT_USERNAME}/.vnc/xstartup
chmod +x /home/${DEFAULT_USERNAME}/.vnc/xstartup

# Set ownership of VNC files
chown -R ${DEFAULT_USERNAME}:${DEFAULT_USERNAME} /home/${DEFAULT_USERNAME}/.vnc

# Install VNC systemd service
cp "${FILES_DIR}/vncserver.service" /etc/systemd/system/vncserver.service
systemctl enable vncserver.service

# Enable SSH server
systemctl enable ssh

echo "✓ Development environment configured successfully!"
echo ""
echo "Configuration Summary:"
echo "  Static IP: ${DEV_STATIC_IP}"
echo "  VNC Server: Port ${DEV_VNC_PORT} (password: ${DEV_VNC_PASSWORD})"
echo "  SSH Server: Enabled"
echo ""
echo "Services will start automatically on first boot."