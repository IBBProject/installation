#!/bin/bash
# set -e
set -o noglob

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"
DAPR_VERSION=1.13

# Set some Variables you probably will not need to change
IBB_INSTALL_DIR="/opt/ibb"
IBB_LOG_PATH="$IBB_INSTALL_DIR/logs"
IBB_LOG_FILE="$IBB_LOG_PATH/install.log"
IBB_DOWNLOAD_PATH="$IBB_INSTALL_DIR/downloads"
REQUIRED_BINARIES="curl cut git grep openssl tr" # FORMAT: "curl wget vim otherbinary"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"
ARGOCD_NS="argocd"
DAPR_NS="dapr-system"
IBB_NS="ibb"
IBB_AUTH_SECRET_NAME="ibb-authorization"
PADI_ONBOARDING_URL="https://api.padi.io/onboarding"
KTUNNEL_KUBECONFIG_SECRET_MANIFEST="./ktunnel-kubectl-secret.yaml"

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

install_cns_dapr () {
  # Install CNS Dapr and it's Redis dependency. Requires helm
  if [ "$INSTALL_CNS_DAPR" != true ]; then 
    log_info "Install cns-dapr flag is not true. Skipping..."
    return 1
  fi

  log_info "Adding IBB Project Helm repository"
  helm repo add ibb https://ibbproject.github.io/helm-charts/ > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Installing redis"
  helm upgrade --install ibb-redis ibb/ibb-redis --namespace default --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  # Create IBB Authentication Secrets
  k3s kubectl create namespace $IBB_NS --dry-run=client -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE
  if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then log_fail "Authentication Not found"; fi
  PADI_ID=$(cat /opt/ibb/padi.json | grep -Po '"padiThing":"([a-zA-Z0-9]+)"' | cut -d ':' -f2 | tr -d '"')
  PADI_TOKEN=$(cat /opt/ibb/padi.json | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' | cut -d ':' -f2 | tr -d '"')
  log_info "Padi Token ${PADI_TOKEN:0:8}"
  if [ -z ${PADI_ID+x} ] || [ -z ${PADI_TOKEN+x} ]; then
    log_fail "Padi ID or Token not set. Exiting"
  fi
  k3s kubectl create secret generic $IBB_AUTH_SECRET_NAME --namespace $IBB_NS --dry-run=client --from-literal=id=$PADI_ID --from-literal=token=$PADI_TOKEN -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE

  # Install CNS Dapr
  log_info "Installing CNS Dapr"
  helm upgrade --install ibb-cns-dapr ibb/ibb-cns-dapr --namespace $IBB_NS --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "CNS Dapr Installed"
}

install_cns_kube () {
  # Install CNS Kube
  if [ "$INSTALL_CNS_KUBE" != true ]; then 
    log_info "Install cns-kube flag is not true. Skipping..."
    return 1
  fi

  log_info "Adding IBB Project Helm repository"
  helm repo add ibb https://ibbproject.github.io/helm-charts/ > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null

  # Verify that IBB Authentication Secret exists
  k3s kubectl get secret --namespace $IBB_NS $IBB_AUTH_SECRET_NAME > /dev/null
  SECRET_EXISTS=$?

  if [ $SECRET_EXISTS -gt 0 ]; then
    log_fail "CNS Kube Authentication Secret does not exist."
  fi

  # Install CNS Kube
  log_info "Installing CNS Kube"
  helm upgrade --install ibb-cns-kube ibb/ibb-cns-kube --namespace $IBB_NS --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "CNS Kube Installed"
}

link_ibb_to_padi() {
  if [ "$LINK_TO_PADI" != true ]; then 
    log_info "Link to Padi flag is not true. Skipping..."
    return 1
  fi

  PADI_INSTALL_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 6; echo)
  log_info ""
  log_info ""
  log_info "Please log into PADI and install a new IBB Instance using the following code"
  log_info "CODE: $PADI_INSTALL_CODE"
  log_info ""
  log_info ""

  MAX_RETRIES=6000
  SLEEP_TIME_SEC=10

  RETRY_COUNT=0
  while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]
  do
    resp_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE)
    log_log "Attempt $RETRY_COUNT of $MAX_RETRIES to $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE was HTTP $resp_code"

    # HTTP 200 is success register, HTTP 403 is fail
    if [ $resp_code -eq 200 ]
    then
      curl -fsSL -o $IBB_INSTALL_DIR/padi.json -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE
      chmod 400 $IBB_INSTALL_DIR/padi.json
      log_info "Successfully registered IBB Instance to Padi"
      return 1
    else
      log_info "Not yet registered. Sleeping."
      RETRY_COUNT=$((RETRY_COUNT + 1))
      sleep "$SLEEP_TIME_SEC"
    fi
  done
  log_fail "Connection Time out. Please rerun this installer to try again"
}

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
  echo -e "[----]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_fail () {
  # [FAIL] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[FAIL]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
  exit 1
}

notify_complete () {
  if [ "$NOTIFY_COMPLETE" != true ]; then 
    log_info "Notify Complete flag is not true. Skipping sending completion..."
    return 1
  fi
  log_info "Notifying Padi Installation is complete"
  TKN=$(cat /opt/ibb/padi.json | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' | cut -d ':' -f2 | tr -d '"')
  log_info "Padi token starts with ${TKN:0:8}"
  curl -X POST \
    -H 'content-type: application/json' \
    -H "authorization: bearer $TKN" \
    -d '"online"' \
    https://api.padi.io/thing/client/padi.node/status
  log_info "Notification Complete"
}

# Start the script

# Start the script
while [[ $# -gt 0 ]]; do
  case $1 in
    --install-dir)
      IBB_INSTALL_DIR=$2
      shift
      shift
      ;;
    --ktunnel-kubeconfig-secret-file)
      KTUNNEL_KUBECONFIG_SECRET_MANIFEST=$2
      shift
      shift
      ;;
    --no-argocd)
      INSTALL_ARGOCD=false
      shift
      ;;
    --no-cns-dapr)
      INSTALL_CNS_DAPR=false
      shift
      ;;
    --no-cns-kube)
      INSTALL_CNS_KUBE=false
      shift
      ;;
    --no-dapr)
      INSTALL_DAPR=false
      shift
      ;;
    --no-helm)
      INSTALL_HELM=false
      shift
      ;;
    --no-k3s)
      INSTALL_K3S=false
      shift
      ;;
    --no-notify-complete)
      NOTIFY_COMPLETE=false
      shift
      ;;
    --no-link-padi)
      LINK_TO_PADI=false
      shift
      ;;
    --no-install-ktunnel)
      INSTALL_KTUNNEL=false
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

check_root
check_required_binaries

# Link must be done before CNS-Dapr or CNS-Kube can be installed
link_ibb_to_padi
install_cns_dapr
install_cns_kube
notify_complete

