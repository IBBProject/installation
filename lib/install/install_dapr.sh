install_dapr() {
  if [ "$INSTALL_DAPR" != true ]; then 
    log_info "Install dapr flag is not true. Skipping..."
    return 0
  fi
  DAPR_HELM_REPO="https://dapr.github.io/helm-charts"
  log_info "Adding Dapr Helm Repo"
  helm repo add dapr "$DAPR_HELM_REPO" > /dev/null
  log_info "Updating Helm Repos"
  helm repo update > /dev/null
  log_info "Installing dapr"
  helm upgrade --install dapr dapr/dapr --namespace $DAPR_NS --create-namespace --version "$DAPR_VERSION" --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  log_info "Finished installing dapr"
}
