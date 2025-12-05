#!/bin/bash
set -e

# Check if development mode is enabled
if [ "${DEVELOPMENT_MODE}" != "true" ]; then
    echo "Development mode is disabled. Skipping static IP setup."
    exit 0
fi

# This script is to contain all of the development processes that are to be added to the system to make it easier to work on
# These are not included in the deliverable. 

export DEV_STATIC_IP="192.168.1.100"
export DEV_VNC_PASSWORD="vnc123"
export DEV_VNC_PORT="5901"