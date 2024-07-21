#!/bin/bash
set -e
set -o noglob

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This `install-ibb.sh` file is dynamically generated. Do not overwrite anything
# in here unless you know what you are doing!
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

INSTALL_SCRIPT_VERSION="1.1.0"

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"
DAPR_VERSION=1.13

# Set some Variables you probably will not need to change
IBB_INSTALL_DIR="/opt/ibb"
IBB_LOG_PATH="$IBB_INSTALL_DIR/logs"
IBB_LOG_FILE="$IBB_LOG_PATH/install.log"
IBB_DOWNLOAD_PATH="$IBB_INSTALL_DIR/downloads"
IBB_KTUNNEL_PATH="$IBB_INSTALL_DIR/ktunnel"
REQUIRED_BINARIES="base64 curl cut git grep openssl tr"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"
ARGOCD_NS="argocd"
DAPR_NS="dapr-system"
IBB_NS="ibb"
IBB_AUTH_SECRET_NAME="ibb-authorization"
PADI_ONBOARDING_URL="https://api.padi.io/onboarding"
PADI_ONBOARDING_CONFIG_URL="https://api.padi.io/onboarding/config/ktunnel"
KTUNNEL_KUBECONFIG_SECRET_MANIFEST="$IBB_KTUNNEL_PATH/ktunnel-auth.yaml"

# Variables set inside functions that need a global scope
ARGOCD_ADMIN_PW=""
PADI_INSTALL_CODE=""

# Set default installations
INSTALL_ARGOCD=false
INSTALL_CNS_DAPR=true
INSTALL_CNS_KUBE=true
INSTALL_DAPR=true
INSTALL_HELM=true
INSTALL_K3S=true
INSTALL_KTUNNEL=true
LINK_TO_PADI=true
NOTIFY_COMPLETE=true
PORT_FORWARD_ARGOCD=true
