install_k3s () {
  if [ "$INSTALL_K3S" != true ]; then 
    log_info "Install K3s flag is not true. Skipping K3S installation..."
    return 0
  fi

  if command -v k3s &>/dev/null
  then
    log_info "Found k3s binary. No need to reinstall."
    return 0
  else
    log_info "Installing K3S Version $K3S_VERSION..."
    K3S_INSTALL_FILE="$IBB_DOWNLOAD_PATH/$K3S_INSTALL_SCRIPT_FILENAME"
    if [[ -f "$K3S_INSTALL_FILE" ]]
    then
      rm "$K3S_INSTALL_FILE"
    fi
    curl -sfL https://get.k3s.io > "$K3S_INSTALL_FILE"
    chmod +x "$K3S_INSTALL_FILE"
    INSTALL_K3S_VERSION=$K3S_VERSION $K3S_INSTALL_FILE | tee -a $IBB_LOG_FILE
  fi
  mkdir -p $HOME/.kube
  cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
  chmod 600 $HOME/.kube/config
}
