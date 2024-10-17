install_argocd () {
  # Install Argo. Requires helm
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_info "Install argo flag is not true. Skipping..."
    return 0
  fi

  if [[ "$ARGOCD_VERSION" == "latest" ]]; then
    log_info "Downloading ArgoCD Manifest"
    curl -fsSLo "$IBB_DOWNLOAD_PATH/argocd-install.yaml" https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  else
    log_fail "Versioning of Argo not yet implemented. Exiting."
  fi

  log_info "Installing ArgoCD. This will take a moment"
  k3s kubectl create namespace $ARGOCD_NS --dry-run=client -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE
  k3s kubectl apply -n $ARGOCD_NS -f "$IBB_DOWNLOAD_PATH/argocd-install.yaml" --wait=true >> $IBB_LOG_FILE
  until k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret > /dev/null 2>&1
  do
    log_info "Waiting for ArgoCD Cluster to become available"
    sleep 10
  done
  ARGOCD_ADMIN_PW=$(k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret -o json | grep "password" | cut -d'"' -f4 | base64 -d)
}
