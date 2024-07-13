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
