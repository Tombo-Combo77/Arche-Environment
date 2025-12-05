#!/bin/bash
set -e

echo "=========================================="
echo "Arche Runtime Service Setup"
echo "=========================================="

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
FILES_DIR="${SCRIPT_DIR}/files"

echo "Installing Arche-runtime systemd service..."

# Copy service file to systemd directory
cp "${FILES_DIR}/Arche-runtime.service" /etc/systemd/system/Arche-runtime.service

# Enable the service
systemctl enable Arche-runtime.service

echo "✓ Arche-runtime service installed and enabled"
echo "  Service is currently a no-op placeholder"
echo "  Ready for future runtime functionality"
