install_cns_kube () {
  # Install CNS Kube
  if [ "$INSTALL_CNS_KUBE" != true ]; then 
    log_info "Install cns-kube flag is not true. Skipping..."
    return 0
  fi

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
  helm upgrade --install ibb-cns-kube ibb/ibb-cns-kube --namespace $IBB_NS --wait | tee -a $IBB_LOG_FILE

  log_info "CNS Kube Installed"
}
