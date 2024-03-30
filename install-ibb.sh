#!/bin/bash
set -e
set -o noglob

# Set some Variables
REQUIRED_BINARIES="curl wget"
K3S_INSTALL_SCRIPT_FILENAME="/tmp/ibb-install-k3s.sh"
# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"

# Check run as root
if [ "$EUID" -ne 0 ]
then
  echo "[!] Setup must be ran as root. Exiting..."
  exit 1
fi

# Check binaries exist on system
for BINARY in $REQUIRED_BINARIES
do
  if [[!  command -v BINARY &> /dev/null ]]
  then
    echo "[!] $BINARY not found. Exiting..."
    exit 1
  fi
done

# Install K3S
if [[ -f "$K3S_INSTALL_SCRIPT_FILENAME" ]]
then
  rm "$K3S_INSTALL_SCRIPT_FILENAME"
fi

echo "[****] Installing K3S Version $K3S_VERSION..."
curl -sfL https://get.k3s.io > "$K3S_INSTALL_SCRIPT_FILENAME"
chmod +x "$K3S_INSTALL_SCRIPT_FILENAME"
INSTALL_K3S_VERSION=$K3S_VERSION $K3S_INSTALL_SCRIPT_FILENAME

# Install Argo

# Add Argo Manifests

