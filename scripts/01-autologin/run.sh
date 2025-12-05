#!/bin/bash
set -e

echo "=========================================="
echo "Autologin Setup"
echo "=========================================="

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
FILES_DIR="${SCRIPT_DIR}/files"

echo "Configuring autologin for user: ${DEFAULT_USERNAME}"

# Install display manager if not present
echo "Ensuring display manager is installed..."
apt-get install -y --no-install-recommends lightdm

# Configure LightDM for autologin
echo "Configuring LightDM autologin..."
mkdir -p /etc/lightdm/lightdm.conf.d
cp "${FILES_DIR}/custom.conf" /etc/lightdm/lightdm.conf.d/50-autologin.conf

# Enable LightDM
systemctl enable lightdm

echo "✓ Autologin configured successfully for user: ${DEFAULT_USERNAME}"
