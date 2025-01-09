check_uninstall () {
  # Uninstall IBB
  if [ "$UNINSTALL" = true ]; then
    log_info "Uninstalling K3S"
    log_info "Removing k3s..."
    /usr/local/bin/k3s-uninstall.sh || true
    log_info "Deleting IBB Directory & KubeConfig"
    rm -rvf "$IBB_INSTALL_DIR" || true
    mv -f "$HOME/.kube/config" "$HOME/.kube/config-bak" || echo "That's okay. Continuing..."
    echo "[****] IBB has been Uninstalled"
    exit 0
  fi
}
