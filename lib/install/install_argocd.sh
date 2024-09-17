install_argocd () {
  # Install Argo. Requires helm
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_info "Install argo flag is not true. Skipping..."
    return 1
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
  sleep 10 # Hack needed for argocd-initial-admin-secret to register with the K8S Cluster
  ARGOCD_ADMIN_PW=$(k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret -o json | grep "password" | cut -d'"' -f4 | base64 -d)
}
