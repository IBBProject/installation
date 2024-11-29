install_k9s () {
  # Install Argo. Requires helm
  if [ "$INSTALL_K9s" != true ]; then 
    log_info "Install k9s flag is not true. Skipping..."
    return 0
  fi

  log_info "Installing K9s. This will take a moment"
  curl -fsSLo "/tmp/k9s.deb" https://raw.githubusercontent.com/derailed/k9s/releases/latest/k9s_linux_amd64.deb
  dpkg -i /tmp/k9s 
}
