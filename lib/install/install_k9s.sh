install_k9s () {
  # Install Argo. Requires helm
  if [ "$INSTALL_K9S" != true ]; then 
    log_info "Install k9s flag is not true. Skipping..."
    return 0
  fi

  log_info "Installing K9s. This will take a moment"
  curl -fsSLo "$IBB_DOWNLOAD_PATH/k9s.deb" \
    https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb
}
