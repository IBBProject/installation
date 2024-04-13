#!/bin/bash
# set -e
set -o noglob

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"

# Set some Variables you probably will not need to change

IBB_INSTALL_DIR="/opt/ibb"
IBB_LOG_PATH="$IBB_INSTALL_DIR/logs"
IBB_LOG_FILE="$IBB_LOG_PATH/install.log"
IBB_DOWNLOAD_PATH="$IBB_INSTALL_DIR/downloads"
REQUIRED_BINARIES="curl" # FORMAT: "curl wget vim otherbinary"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"
ARGOCD_NS="argocd"
PADI_ONBOARDING_URL="https://api.padi.io/onboarding"

# Variables set inside functions that need a global scope
ARGOCD_ADMIN_PW=""
PADI_INSTALL_CODE=""

# Set default installations
INSTALL_ARGOCD=true
INSTALL_HELM=true
INSTALL_K3S=true
LINK_TO_PADI=true
PORT_FORWARD_ARGOCD=true


# Check binaries exist on system
check_required_binaries () {
  for BINARY in $REQUIRED_BINARIES
  do
    log_debug "Checking for $BINARY"
    if !  command -v $BINARY &>/dev/null
    then
      log_fail "$BINARY not found. Exiting..."
    fi
  done
}

# Check that script is running as root
check_root () {
  if [ "$EUID" -ne 0 ]
  then
    log_fail "Setup must be ran as root."
  fi
}

check_uninstall () {
  if [ "$UNINSTALL" = true ]; then
    log_debug "Uninstalling K3S"
    /usr/local/bin/k3s-uninstall.sh &>/dev/null
    log_debug "Deleting IBB Directory"
    rm -rf "$IBB_INSTALL_DIR"
    echo "[****] IBB has been Installed"
    exit 1
  fi
}

create_ibb_install_dir () {
  # Create IBB Install Directory
  if [ ! -d "$IBB_INSTALL_DIR" ]; then
    mkdir -p "$IBB_LOG_PATH" # Log path must exist before we can log_debug
    log_debug "Creating IBB directory $IBB_LOG_PATH"
    log_debug "Creating IBB directory $IBB_DOWNLOAD_PATH"
    mkdir -p "$IBB_DOWNLOAD_PATH"
  else
    log_debug "IBB Directory already at $IBB_INSTALL_DIR"
  fi
}

display_complete () {
  log_debug ""
  log_debug ""
  log_debug "INSTALLATION COMPLETE"
  log_debug "ArgoCD Should be accessable at  https://$LOCAL_IP:8080"
  log_debug "   Username: admin"
  log_debug "   Password: $ARGOCD_ADMIN_PW"
  log_debug ""
  log_debug ""
}

# Install Argo. Requires helm
install_argocd () {
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_debug "Install argo flag is not true. Skipping..."
    return 1
  fi
  if [[ "$ARGOCD_VERSION" == "latest" ]]; then
    log_debug "Downloading ArgoCD Manifest"
    curl -fsSLo "$IBB_DOWNLOAD_PATH/argocd-install.yaml" https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  else
    log_fail "Versioning of Argo not yet implemented. Exiting."
  fi

  log_debug "Installing ArgoCD. This may take a moment"
  k3s kubectl create namespace $ARGOCD_NS --dry-run=client -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE
  k3s kubectl apply -n $ARGOCD_NS -f "$IBB_DOWNLOAD_PATH/argocd-install.yaml" --wait=true >> $IBB_LOG_FILE
  sleep 10 # Hack needed for argocd-initial-admin-secret to register with the K8S Cluster
  ARGOCD_ADMIN_PW=$(k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret -o json | grep "password" | cut -d'"' -f4 | base64 -d)
}

# Install Helm
install_helm () {
  if [ "$INSTALL_HELM" != true ]; then 
    log_debug "Install helm flag is not true. Skipping helm installation..."
    return 1
  fi
  if command -v helm &>/dev/null
  then
    log_debug "Found helm binary. No need to reinstall."
  else
    log_debug "Installing helm..."

    HELM_INSTALL_SCRIPT="$IBB_DOWNLOAD_PATH/$HELM_INSTALL_SCRIPT_FILENAME"
    if [[ -f "$HELM_INSTALL_SCRIPT" ]]
    then
      rm "$HELM_INSTALL_SCRIPT"
    fi
    curl -fsSL -o $HELM_INSTALL_SCRIPT https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 $HELM_INSTALL_SCRIPT
    $HELM_INSTALL_SCRIPT | tee -a $IBB_LOG_FILE
  fi
}

# # Install K3S
install_k3s () {
  if [ "$INSTALL_K3S" != true ]; then 
    log_debug "Install K3s flag is not true. Skipping K3S installation..."
    return 1
  fi

  if command -v k3s &>/dev/null
  then
    log_debug "Found k3s binary. No need to reinstall."
  else
    log_debug "Installing K3S Version $K3S_VERSION..."
    K3S_INSTALL_FILE="$IBB_DOWNLOAD_PATH/$K3S_INSTALL_SCRIPT_FILENAME"
    if [[ -f "$K3S_INSTALL_FILE" ]]
    then
      rm "$K3S_INSTALL_FILE"
    fi
    curl -sfL https://get.k3s.io > "$K3S_INSTALL_FILE"
    chmod +x "$K3S_INSTALL_FILE"
    INSTALL_K3S_VERSION=$K3S_VERSION $K3S_INSTALL_FILE | tee -a $IBB_LOG_FILE
  fi
}

link_ibb_to_padi() {
  if [ "$LINK_TO_PADI" != true ]; then 
    log_debug "Link to Padi flag is not true. Skipping..."
    return 1
  fi

  PADI_INSTALL_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 6; echo)
  # PADI_INSTALL_CODE="ABCDEFG"
  log_debug ""
  log_debug ""
  log_debug "Please log into PADI and install a new IBB Instance using the following code"
  log_debug "CODE: $PADI_INSTALL_CODE"
  log_debug ""
  log_debug ""

  MAX_RETRIES=5
  SLEEP_TIME_SEC=3

  RETRY_COUNT=0
  while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]
  do
    # HTTP 200 is success register, HTTP 403 is fail
    resp_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE)

    if [ $resp_code -eq 200 ]
    then
      curl -fsSL -o $IBB_INSTALL_DIR/padi.json -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE
      chmod 400 $IBB_INSTALL_DIR/padi.json
      log_debug "Successfully registered IBB Instance to Padi"
      return 1
    else
      log_debug "Not yet registered. Sleeping."
      RETRY_COUNT=$((RETRY_COUNT + 1))
      sleep "$SLEEP_TIME_SEC"
    fi
    log_fail "Connection Time out. Please rerun this installer to try again"
  done
}

log_debug () {
  # [***] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[****]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_fail () {
  # [FAIL] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[FAIL]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
  exit 1
}

# Port-forward ArgoCD for users to log in
port_forward_argocd () {
  if [ "$PORT_FORWARD_ARGOCD" != true ]; then 
    log_debug "Port forwarding of ArgoCd is not true. Skipping."
    return 1
  fi
  LOCAL_IP=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f7)
  PORT=8080

  # Kill any other processes running on port 8080 
  PORT_8080_PID=$(lsof -i tcp:$PORT | awk 'NR!=1 {print $2}')
  if [ ! -z "${PORT_8080_PID}" ]
  then
    echo "[****] Killing $PORT_8080_PID"
    kill $PORT_8080_PID > /dev/null
  fi

  k3s kubectl port-forward --address=0.0.0.0 -n $ARGOCD_NS svc/argocd-server $PORT:80 &
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -a|--argocd)
      INSTALL_ARGOCD=$2
      shift
      shift
      ;;
    -d|--install-dir)
      IBB_INSTALL_DIR=$2
      shift
      shift
      ;;
    -h|--helm)
      INSTALL_HELM=$2
      shift
      shift
      ;;
    -k|--k3s)
      INSTALL_K3S=$2
      shift
      shift
      ;;
    -p|--padi)
      LINK_TO_PADI=$2
      shift
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

check_root
check_uninstall
create_ibb_install_dir
check_required_binaries

install_k3s
install_helm
install_argocd
port_forward_argocd
link_ibb_to_padi

display_complete
