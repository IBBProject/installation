check_uninstall () {
  # Uninstall IBB
  if [ "$UNINSTALL" = true ]; then
    log_info "Uninstalling K3S"
    /usr/local/bin/k3s-uninstall.sh || true
    log_info "Deleting IBB Directory"
    rm -rvf "$IBB_INSTALL_DIR" || true
    echo "[****] IBB has been Uninstalled"
    exit 0
  fi
}
