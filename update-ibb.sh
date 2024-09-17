#!/bin/bash
set -e
set -o noglob

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This file is dynamically generated. Do not overwrite anything
# in here unless you know what you are doing!
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

INSTALL_SCRIPT_VERSION="1.3.0"

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
log_err () {
  # [!!!!] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[!!!!]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_info () {
  # [***] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[****]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_log () {
  # [----] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[----]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" >> $IBB_LOG_FILE
}

log_fail () {
  # [FAIL] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[FAIL]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
  exit 1
}
check_root () {
  # Check that script is running as root
  if [ "$EUID" -ne 0 ]
  then
    log_fail "Setup must be ran as root."
  fi
}
check_required_binaries () {
  # Check binaries exist on system
  for BINARY in $REQUIRED_BINARIES
  do
    log_info "Checking for $BINARY"
    if !  command -v $BINARY &>/dev/null
    then
      log_fail "$BINARY not found. Exiting..."
    fi
    if [[ "$BINARY" -eq "grep" ]]; then
      log_info "Checking grep version"
      grep --version | grep "GNU grep" > /dev/null
      GNU_GREP=$?
      if [[ "$GNU_GREP" -gt 0 ]]; then
        log_fail "GNU Grep is not installed. Please install and try again"
      fi
    fi
  done
}
create_ibb_install_dir () {
  # Create IBB Install Directory
  if [ ! -d "$IBB_INSTALL_DIR" ]; then
    mkdir -p "$IBB_LOG_PATH" # Log path must exist before we can log_info
    log_info "Creating IBB directory $IBB_LOG_PATH"
    log_info "Creating IBB directory $IBB_DOWNLOAD_PATH"
    mkdir -p "$IBB_DOWNLOAD_PATH"
  else
    log_info "IBB Directory already at $IBB_INSTALL_DIR"
  fi
}
update_ktunnel () {
  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Updating ktunnel sidecar injector"
  helm upgrade --install ibb-ktunnel-inejctor ibb/ibb-ktunnel-injector --namespace kube-system --set-file caCrt=$IBB_INSTALL_DIR/ktunnel/ca.crt,sidecarInjectorCrt=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt,sidecarInjectorKey=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  KTUNNEL_VERSION=$(helm search repo ibb/ibb-ktunnel-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-ktunnel-injector is now on version $KTUNNEL_VERSION"
}

check_root
create_ibb_install_dir
check_required_binaries
update_ktunnel

