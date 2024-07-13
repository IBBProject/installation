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
